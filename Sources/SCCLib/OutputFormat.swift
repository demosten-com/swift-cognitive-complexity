import Foundation

public enum OutputFormat: String, Sendable, CaseIterable {
    case text
    case json
    case github
    case markdown

    public func format(_ report: ProjectReport, verbose: Bool, violationsOnly: Bool = false) -> String {
        switch self {
        case .text:
            return formatText(report, verbose: verbose, violationsOnly: violationsOnly)
        case .json:
            return formatJSON(report, violationsOnly: violationsOnly)
        case .github:
            return formatGitHub(report)
        case .markdown:
            return formatMarkdown(report)
        }
    }

    // MARK: - Text Format

    private func formatText(_ report: ProjectReport, verbose: Bool, violationsOnly: Bool = false) -> String {
        var lines: [String] = []
        var currentFile = ""

        for file in report.files {
            let hasOutput: Bool
            if violationsOnly {
                hasOutput = file.functions.contains(where: { $0.complexity > report.warningThreshold })
            } else {
                hasOutput = verbose || file.functions.contains(where: { $0.complexity > 0 })
            }
            guard hasOutput else { continue }

            if file.path != currentFile {
                currentFile = file.path
                lines.append(currentFile)
            }

            lines += formatFileFunctions(file, report: report, verbose: verbose, violationsOnly: violationsOnly)
        }

        lines.append("")
        lines.append("Summary: \(report.analyzedFileCount) files, \(report.analyzedFunctionCount) functions analyzed")
        let warnCount = report.functionsAboveWarning.count
        let errCount = report.functionsAboveError.count
        if warnCount > 0 {
            lines.append("Functions above warning threshold (\(report.warningThreshold)): \(warnCount)")
        }
        if errCount > 0 {
            lines.append("Functions above error threshold (\(report.errorThreshold)): \(errCount)")
        }
        lines.append("Total project complexity: \(formatNumber(report.totalComplexity))")
        lines.append(String(format: "Elapsed: %.2fs", report.elapsedSeconds))

        return lines.joined(separator: "\n")
    }

    private func formatFileFunctions(_ file: FileReport, report: ProjectReport, verbose: Bool, violationsOnly: Bool) -> [String] {
        var lines: [String] = []
        for fn in file.functions {
            if violationsOnly && fn.complexity <= report.warningThreshold { continue }
            if !violationsOnly && !verbose && fn.complexity == 0 { continue }

            var line = "  \(fn.name)"
            line += String(repeating: " ", count: max(1, 40 - fn.name.count))
            line += "line \(fn.line)"
            line += String(repeating: " ", count: max(1, 8 - String(fn.line).count))
            line += "complexity: \(fn.complexity)"

            if fn.complexity > report.errorThreshold {
                line += "  \u{274C} exceeds error threshold (\(report.errorThreshold))"
            } else if fn.complexity > report.warningThreshold {
                line += "  \u{26A0}\u{FE0F} exceeds threshold (\(report.warningThreshold))"
            }

            lines.append(line)

            if verbose {
                for detail in fn.details {
                    lines.append("    line \(detail.line): \(detail.description)")
                }
            }
        }
        return lines
    }

    // MARK: - JSON Format

    private func formatJSON(_ report: ProjectReport, violationsOnly: Bool = false) -> String {
        let filteredFiles: [FileReport]
        if violationsOnly {
            filteredFiles = report.files.compactMap { file in
                let fns = file.functions.filter { $0.complexity > report.warningThreshold }
                guard !fns.isEmpty else { return nil }
                return FileReport(path: file.path, functions: fns)
            }
        } else {
            filteredFiles = report.files
        }

        let jsonReport = JSONReport(
            summary: JSONSummary(
                totalFiles: report.analyzedFileCount,
                totalFunctions: report.analyzedFunctionCount,
                totalComplexity: report.totalComplexity,
                warningThreshold: report.warningThreshold,
                errorThreshold: report.errorThreshold,
                warningCount: report.functionsAboveWarning.count,
                errorCount: report.functionsAboveError.count,
                elapsedMs: Int(report.elapsedSeconds * 1000)
            ),
            files: filteredFiles.map { file in
                JSONFile(
                    path: file.path,
                    functions: file.functions.map { fn in
                        JSONFunction(
                            name: fn.name,
                            line: fn.line,
                            column: fn.column,
                            complexity: fn.complexity,
                            status: status(for: fn, report: report),
                            increments: fn.details.map { detail in
                                JSONIncrement(
                                    line: detail.line,
                                    increment: detail.increment,
                                    description: detail.description
                                )
                            }
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(jsonReport),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    // MARK: - GitHub Format

    private func formatGitHub(_ report: ProjectReport) -> String {
        var lines: [String] = []

        for file in report.files {
            for fn in file.functions {
                if fn.complexity > report.errorThreshold {
                    lines.append("::error file=\(fn.filePath),line=\(fn.line),col=\(fn.column),title=Cognitive Complexity::Function \(fn.name) has cognitive complexity \(fn.complexity) (threshold: \(report.errorThreshold))")
                } else if fn.complexity > report.warningThreshold {
                    lines.append("::warning file=\(fn.filePath),line=\(fn.line),col=\(fn.column),title=Cognitive Complexity::Function \(fn.name) has cognitive complexity \(fn.complexity) (threshold: \(report.warningThreshold))")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Markdown Format

    private func formatMarkdown(_ report: ProjectReport) -> String {
        var lines: [String] = []

        let warnCount = report.functionsAboveWarning.count
        let errCount = report.functionsAboveError.count

        lines.append("## Cognitive Complexity Report")
        lines.append("")

        if warnCount > 0 {
            lines.append("**\(warnCount) function\(warnCount == 1 ? "" : "s")** exceed the warning threshold (\(report.warningThreshold))")
        }
        if errCount > 0 {
            lines.append("**\(errCount) function\(errCount == 1 ? "" : "s")** exceed the error threshold (\(report.errorThreshold))")
        }
        if warnCount == 0 && errCount == 0 {
            lines.append("No functions exceed the complexity thresholds.")
            lines.append("")
            lines.append("**\(report.analyzedFileCount)** files, **\(report.analyzedFunctionCount)** functions analyzed. Total complexity: **\(formatNumber(report.totalComplexity))**")
            return lines.joined(separator: "\n")
        }

        lines.append("")
        lines.append("| File | Function | Line | Complexity | Status |")
        lines.append("|------|----------|------|------------|--------|")

        for file in report.files {
            let fileName = (file.path as NSString).lastPathComponent
            for fn in file.functions {
                if fn.complexity > report.errorThreshold {
                    lines.append("| `\(fileName)` | `\(fn.name)` | \(fn.line) | \(fn.complexity) | :x: |")
                } else if fn.complexity > report.warningThreshold {
                    lines.append("| `\(fileName)` | `\(fn.name)` | \(fn.line) | \(fn.complexity) | :warning: |")
                }
            }
        }

        lines.append("")
        lines.append("**\(report.analyzedFileCount)** files, **\(report.analyzedFunctionCount)** functions analyzed. Total complexity: **\(formatNumber(report.totalComplexity))**")

        return lines.joined(separator: "\n")
    }

    // MARK: - Diff Report Formatting

    public func format(_ report: DiffReport, verbose: Bool, violationsOnly: Bool = false) -> String {
        switch self {
        case .text:
            return formatDiffText(report, verbose: verbose)
        case .json:
            return formatDiffJSON(report)
        case .github:
            return formatDiffGitHub(report)
        case .markdown:
            return formatDiffMarkdown(report)
        }
    }

    private func formatDiffText(_ report: DiffReport, verbose: Bool) -> String {
        var lines: [String] = []

        let sign = report.totalDelta >= 0 ? "+" : ""
        lines.append("Diff Analysis: \(report.changedFiles.count) changed file\(report.changedFiles.count == 1 ? "" : "s"), delta: \(sign)\(report.totalDelta)")
        lines.append("")

        for file in report.changedFiles {
            lines.append("\(file.path)  (\(file.beforeComplexity) -> \(file.afterComplexity), \(file.delta >= 0 ? "+" : "")\(file.delta))")

            for fd in file.functionDeltas {
                var line = "  \(fd.name)"
                line += String(repeating: " ", count: max(1, 40 - fd.name.count))
                line += formatFunctionDeltaSuffix(fd)
                lines.append(line)
            }
        }

        lines.append("")
        if !report.newViolations.isEmpty {
            lines.append("New violations: \(report.newViolations.count)")
        }
        if !report.resolvedViolations.isEmpty {
            lines.append("Resolved violations: \(report.resolvedViolations.count)")
        }
        lines.append(String(format: "Elapsed: %.2fs", report.elapsedSeconds))

        return lines.joined(separator: "\n")
    }

    private func formatFunctionDeltaSuffix(_ fd: FunctionDelta) -> String {
        if let before = fd.beforeComplexity, let after = fd.afterComplexity {
            return "\(before) -> \(after) (\(fd.delta >= 0 ? "+" : "")\(fd.delta))"
        } else if fd.beforeComplexity == nil {
            return "new (complexity: \(fd.afterComplexity ?? 0))"
        } else {
            return "deleted (was: \(fd.beforeComplexity ?? 0))"
        }
    }

    private func formatDiffJSON(_ report: DiffReport) -> String {
        let jsonReport = DiffJSONReport(
            summary: DiffJSONSummary(
                changedFiles: report.changedFiles.count,
                totalDelta: report.totalDelta,
                warningThreshold: report.warningThreshold,
                errorThreshold: report.errorThreshold,
                newViolationCount: report.newViolations.count,
                resolvedViolationCount: report.resolvedViolations.count,
                elapsedMs: Int(report.elapsedSeconds * 1000)
            ),
            files: report.changedFiles.map { file in
                DiffJSONFile(
                    path: file.path,
                    beforeComplexity: file.beforeComplexity,
                    afterComplexity: file.afterComplexity,
                    delta: file.delta,
                    functions: file.functionDeltas.map { fd in
                        DiffJSONFunction(
                            name: fd.name,
                            line: fd.line,
                            beforeComplexity: fd.beforeComplexity,
                            afterComplexity: fd.afterComplexity,
                            delta: fd.delta
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(jsonReport),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func formatDiffGitHub(_ report: DiffReport) -> String {
        var lines: [String] = []

        for violation in report.newViolations {
            if violation.complexity > report.errorThreshold {
                lines.append("::error file=\(violation.filePath),line=\(violation.line),col=\(violation.column),title=Cognitive Complexity::Function \(violation.name) has cognitive complexity \(violation.complexity) (threshold: \(report.errorThreshold))")
            } else {
                lines.append("::warning file=\(violation.filePath),line=\(violation.line),col=\(violation.column),title=Cognitive Complexity::Function \(violation.name) has cognitive complexity \(violation.complexity) (threshold: \(report.warningThreshold))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatDiffMarkdown(_ report: DiffReport) -> String {
        var lines: [String] = []

        let sign = report.totalDelta >= 0 ? "+" : ""
        lines.append("## Cognitive Complexity -- PR Impact")
        lines.append("")
        lines.append("**Overall delta: \(sign)\(report.totalDelta)**")
        lines.append("")

        lines += formatNewViolationsMarkdown(report)
        lines += formatResolvedViolationsMarkdown(report)
        lines += formatChangedFunctionsMarkdown(report)

        return lines.joined(separator: "\n")
    }

    private func formatNewViolationsMarkdown(_ report: DiffReport) -> [String] {
        guard !report.newViolations.isEmpty else { return [] }
        var lines: [String] = []
        lines.append("### New violations (\(report.newViolations.count))")
        lines.append("")
        lines.append("| File | Function | Complexity | Threshold |")
        lines.append("|------|----------|------------|-----------|")
        for fn in report.newViolations {
            let fileName = (fn.filePath as NSString).lastPathComponent
            let threshold = fn.complexity > report.errorThreshold ? "\(report.errorThreshold) :x:" : "\(report.warningThreshold) :warning:"
            lines.append("| `\(fileName)` | `\(fn.name)` | \(fn.complexity) | \(threshold) |")
        }
        lines.append("")
        return lines
    }

    private func formatResolvedViolationsMarkdown(_ report: DiffReport) -> [String] {
        guard !report.resolvedViolations.isEmpty else { return [] }
        var lines: [String] = []
        lines.append("### Resolved violations (\(report.resolvedViolations.count))")
        lines.append("")
        lines.append("| File | Function | Before | After |")
        lines.append("|------|----------|--------|-------|")
        for fn in report.resolvedViolations {
            let fileName = (fn.filePath as NSString).lastPathComponent
            lines.append("| `\(fileName)` | `\(fn.name)` | \(fn.complexity) | :white_check_mark: |")
        }
        lines.append("")
        return lines
    }

    private func formatChangedFunctionsMarkdown(_ report: DiffReport) -> [String] {
        let hasChanges = report.changedFiles.contains { $0.functionDeltas.contains { $0.delta != 0 } }
        guard hasChanges else { return [] }
        var lines: [String] = []
        lines.append("### Changed functions")
        lines.append("")
        lines.append("| File | Function | Before | After | Delta |")
        lines.append("|------|----------|--------|-------|-------|")
        for file in report.changedFiles {
            let fileName = (file.path as NSString).lastPathComponent
            for fd in file.functionDeltas where fd.delta != 0 {
                lines.append(formatFunctionDeltaRow(fileName: fileName, fd))
            }
        }
        return lines
    }

    private func formatFunctionDeltaRow(fileName: String, _ fd: FunctionDelta) -> String {
        let before = fd.beforeComplexity.map(String.init) ?? "--"
        let after = fd.afterComplexity.map(String.init) ?? "--"
        let deltaStr = fd.beforeComplexity == nil ? "new" : (fd.afterComplexity == nil ? "deleted" : "\(fd.delta >= 0 ? "+" : "")\(fd.delta)")
        return "| `\(fileName)` | `\(fd.name)` | \(before) | \(after) | \(deltaStr) |"
    }

    // MARK: - Helpers

    private func status(for fn: FunctionComplexity, report: ProjectReport) -> String {
        if fn.complexity > report.errorThreshold { return "error" }
        if fn.complexity > report.warningThreshold { return "warning" }
        return "ok"
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - JSON Encodable Types

private struct JSONReport: Encodable {
    let summary: JSONSummary
    let files: [JSONFile]
}

private struct JSONSummary: Encodable {
    let totalFiles: Int
    let totalFunctions: Int
    let totalComplexity: Int
    let warningThreshold: Int
    let errorThreshold: Int
    let warningCount: Int
    let errorCount: Int
    let elapsedMs: Int
}

private struct JSONFile: Encodable {
    let path: String
    let functions: [JSONFunction]
}

private struct JSONFunction: Encodable {
    let name: String
    let line: Int
    let column: Int
    let complexity: Int
    let status: String
    let increments: [JSONIncrement]
}

private struct JSONIncrement: Encodable {
    let line: Int
    let increment: Int
    let description: String
}

// MARK: - Diff JSON Encodable Types

private struct DiffJSONReport: Encodable {
    let summary: DiffJSONSummary
    let files: [DiffJSONFile]
}

private struct DiffJSONSummary: Encodable {
    let changedFiles: Int
    let totalDelta: Int
    let warningThreshold: Int
    let errorThreshold: Int
    let newViolationCount: Int
    let resolvedViolationCount: Int
    let elapsedMs: Int
}

private struct DiffJSONFile: Encodable {
    let path: String
    let beforeComplexity: Int
    let afterComplexity: Int
    let delta: Int
    let functions: [DiffJSONFunction]
}

private struct DiffJSONFunction: Encodable {
    let name: String
    let line: Int
    let beforeComplexity: Int?
    let afterComplexity: Int?
    let delta: Int
}
