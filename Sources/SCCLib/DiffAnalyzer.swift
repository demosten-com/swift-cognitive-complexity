import Foundation

public struct DiffAnalyzer<G: GitOperations>: Sendable {
    public let configuration: Configuration
    public let gitOperations: G
    public let analyzer: ProjectAnalyzer

    public init(configuration: Configuration, gitOperations: G, maxConcurrency: Int? = nil) {
        self.configuration = configuration
        self.gitOperations = gitOperations
        self.analyzer = ProjectAnalyzer(configuration: configuration, maxConcurrency: maxConcurrency)
    }

    public func analyze(baseRef: String, changedFiles: [String]? = nil) async throws -> DiffReport {
        let start = Date().timeIntervalSinceReferenceDate

        let repoRoot = try gitOperations.repositoryRoot()
        let relativePaths: [String]
        if let changedFiles {
            relativePaths = changedFiles
        } else {
            relativePaths = try gitOperations.changedSwiftFiles(baseRef: baseRef)
        }

        let filter = FileDiscovery(
            includePaths: configuration.includePaths,
            excludePaths: configuration.excludePaths
        )
        let filtered = relativePaths.filter { filter.shouldInclude(path: $0) }

        var fileDiffs: [FileDiffReport] = []
        var newViolations: [FunctionComplexity] = []
        var resolvedViolations: [FunctionComplexity] = []

        for relativePath in filtered {
            let (beforeFunctions, afterFunctions) = try analyzeFileComplexity(
                relativePath: relativePath, baseRef: baseRef, repoRoot: repoRoot
            )

            let functionDeltas = computeFunctionDeltas(
                before: beforeFunctions,
                after: afterFunctions
            )

            let beforeComplexity = beforeFunctions.reduce(0) { $0 + $1.complexity }
            let afterComplexity = afterFunctions.reduce(0) { $0 + $1.complexity }

            fileDiffs.append(FileDiffReport(
                path: relativePath,
                beforeComplexity: beforeComplexity,
                afterComplexity: afterComplexity,
                delta: afterComplexity - beforeComplexity,
                functionDeltas: functionDeltas
            ))

            newViolations += detectNewViolations(before: beforeFunctions, after: afterFunctions, threshold: configuration.warningThreshold)
            resolvedViolations += detectResolvedViolations(before: beforeFunctions, after: afterFunctions, threshold: configuration.warningThreshold)
        }

        let totalDelta = fileDiffs.reduce(0) { $0 + $1.delta }
        let elapsed = Date().timeIntervalSinceReferenceDate - start

        return DiffReport(
            changedFiles: fileDiffs.sorted { $0.path < $1.path },
            totalDelta: totalDelta,
            warningThreshold: configuration.warningThreshold,
            errorThreshold: configuration.errorThreshold,
            newViolations: newViolations,
            resolvedViolations: resolvedViolations,
            elapsedSeconds: elapsed
        )
    }

    private func analyzeFileComplexity(
        relativePath: String, baseRef: String, repoRoot: String
    ) throws -> (before: [FunctionComplexity], after: [FunctionComplexity]) {
        let absolutePath = repoRoot.hasSuffix("/")
            ? repoRoot + relativePath
            : repoRoot + "/" + relativePath

        let afterFunctions: [FunctionComplexity]
        if let afterSource = try? String(contentsOfFile: absolutePath, encoding: .utf8) {
            afterFunctions = analyzer.analyzeSource(afterSource, filePath: relativePath).functions
        } else {
            afterFunctions = []
        }

        let baseSource = try gitOperations.fileContent(at: relativePath, ref: baseRef)
        let beforeFunctions: [FunctionComplexity]
        if let baseSource {
            beforeFunctions = analyzer.analyzeSource(baseSource, filePath: relativePath).functions
        } else {
            beforeFunctions = []
        }

        return (before: beforeFunctions, after: afterFunctions)
    }

    private func detectNewViolations(
        before: [FunctionComplexity], after: [FunctionComplexity], threshold: Int
    ) -> [FunctionComplexity] {
        var violations: [FunctionComplexity] = []
        for afterFn in after where afterFn.complexity > threshold {
            let beforeFn = before.first { $0.name == afterFn.name }
            if beforeFn == nil || beforeFn!.complexity <= threshold {
                violations.append(afterFn)
            }
        }
        return violations
    }

    private func detectResolvedViolations(
        before: [FunctionComplexity], after: [FunctionComplexity], threshold: Int
    ) -> [FunctionComplexity] {
        var violations: [FunctionComplexity] = []
        for beforeFn in before where beforeFn.complexity > threshold {
            let afterFn = after.first { $0.name == beforeFn.name }
            if afterFn == nil || afterFn!.complexity <= threshold {
                violations.append(beforeFn)
            }
        }
        return violations
    }

    private func computeFunctionDeltas(
        before: [FunctionComplexity],
        after: [FunctionComplexity]
    ) -> [FunctionDelta] {
        var deltas: [FunctionDelta] = []

        // Group by name, preserving order for overload matching
        var beforeByName: [String: [FunctionComplexity]] = [:]
        for fn in before {
            beforeByName[fn.name, default: []].append(fn)
        }

        var matched: Set<String> = [] // "name:index" keys to track consumed before entries
        var afterByName: [String: Int] = [:] // count of how many of each name we've seen

        for fn in after {
            let idx = afterByName[fn.name, default: 0]
            afterByName[fn.name] = idx + 1

            let key = "\(fn.name):\(idx)"
            if let beforeList = beforeByName[fn.name], idx < beforeList.count {
                let beforeFn = beforeList[idx]
                matched.insert(key)
                deltas.append(FunctionDelta(
                    name: fn.name,
                    line: fn.line,
                    beforeComplexity: beforeFn.complexity,
                    afterComplexity: fn.complexity,
                    delta: fn.complexity - beforeFn.complexity
                ))
            } else {
                // New function
                deltas.append(FunctionDelta(
                    name: fn.name,
                    line: fn.line,
                    beforeComplexity: nil,
                    afterComplexity: fn.complexity,
                    delta: fn.complexity
                ))
            }
        }

        // Deleted functions (in before but not consumed)
        for (name, list) in beforeByName {
            let consumedCount = afterByName[name] ?? 0
            for idx in consumedCount..<list.count {
                let fn = list[idx]
                deltas.append(FunctionDelta(
                    name: fn.name,
                    line: 0,
                    beforeComplexity: fn.complexity,
                    afterComplexity: nil,
                    delta: -fn.complexity
                ))
            }
        }

        return deltas
    }
}
