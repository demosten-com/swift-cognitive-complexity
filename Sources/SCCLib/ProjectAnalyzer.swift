//
// Swift Cognitive Complexity (scc)
//
// Copyright (c) 2026 Stanimir Karoserov.
// Licensed under the MIT License. See LICENSE file for details.
// SPDX-License-Identifier: MIT
//
import Foundation
import SwiftParser
import SwiftSyntax

public struct ProjectAnalyzer: Sendable {
    public let configuration: Configuration
    public let maxConcurrency: Int

    public init(configuration: Configuration, maxConcurrency: Int? = nil) {
        self.configuration = configuration
        self.maxConcurrency = maxConcurrency ?? ProcessInfo.processInfo.activeProcessorCount
    }

    public func analyze(paths: [String]) async throws -> ProjectReport {
        let start = Date().timeIntervalSinceReferenceDate
        let discovery = FileDiscovery(
            includePaths: configuration.includePaths,
            excludePaths: configuration.excludePaths
        )
        let files = try discovery.discoverFiles(in: paths)
        let basePath = resolveBasePath(for: paths)

        let reports = await analyzeFilesConcurrently(files, basePath: basePath)

        let elapsed = Date().timeIntervalSinceReferenceDate - start
        return ProjectReport(
            files: reports.sorted { $0.path < $1.path },
            warningThreshold: configuration.warningThreshold,
            errorThreshold: configuration.errorThreshold,
            elapsedSeconds: elapsed
        )
    }

    private func analyzeFilesConcurrently(_ files: [String], basePath: String) async -> [FileReport] {
        await withTaskGroup(of: FileReport?.self) { group in
            var inFlight = 0
            var fileIterator = files.makeIterator()
            var results: [FileReport] = []

            // Seed initial batch
            while inFlight < maxConcurrency, let file = fileIterator.next() {
                group.addTask { [self] in self.analyzeFile(at: file, basePath: basePath) }
                inFlight += 1
            }

            // As each completes, add the next
            for await result in group {
                inFlight -= 1
                if let report = result {
                    results.append(report)
                }
                if let file = fileIterator.next() {
                    group.addTask { [self] in self.analyzeFile(at: file, basePath: basePath) }
                    inFlight += 1
                }
            }

            return results
        }
    }

    public func analyzeFile(at path: String, basePath: String? = nil) -> FileReport? {
        do {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let fileSize = attrs[.size] as? Int,
               fileSize > configuration.maxFileSize {
                FileHandle.standardError.write(Data("Warning: Skipping '\(path)' (\(fileSize) bytes exceeds max-file-size \(configuration.maxFileSize))\n".utf8))
                return nil
            }
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let displayPath = basePath.map { makeRelativePath(path, basePath: $0) } ?? path
            return analyzeSource(source, filePath: displayPath)
        } catch {
            FileHandle.standardError.write(Data("Warning: Failed to analyze '\(path)': \(error)\n".utf8))
            return nil
        }
    }

    // MARK: - Path Helpers

    private func resolveBasePath(for paths: [String]) -> String {
        let fm = FileManager.default
        guard paths.count == 1, let root = paths.first else {
            return fm.currentDirectoryPath
        }
        let absolute = root.hasPrefix("/") ? root : fm.currentDirectoryPath + "/" + root
        let normalized = (absolute as NSString).standardizingPath

        var isDir: ObjCBool = false
        if fm.fileExists(atPath: normalized, isDirectory: &isDir), !isDir.boolValue {
            return (normalized as NSString).deletingLastPathComponent
        }
        return normalized
    }

    private func makeRelativePath(_ absolutePath: String, basePath: String) -> String {
        let base = basePath.hasSuffix("/") ? basePath : basePath + "/"
        if absolutePath.hasPrefix(base) {
            return String(absolutePath.dropFirst(base.count))
        }
        return absolutePath
    }

    public func analyzeSource(_ source: String, filePath: String) -> FileReport {
        let sourceFile = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: filePath, tree: sourceFile)
        let visitor = CognitiveComplexityVisitor(
            converter: converter,
            filePath: filePath,
            swiftUIAware: configuration.swiftuiAware,
            swiftUIContainers: Set(configuration.swiftuiContainers)
        )
        visitor.walk(sourceFile)
        return FileReport(path: filePath, functions: visitor.results)
    }
}
