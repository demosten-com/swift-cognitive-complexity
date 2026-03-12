//
// Swift Cognitive Complexity (scc)
//
// Copyright (c) 2026 Stanimir Karoserov.
// Licensed under the MIT License. See LICENSE file for details.
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing
@testable import SCCLib

private func makeSampleDiffReport() -> DiffReport {
    let newViolation = FunctionComplexity(
        name: "complexFunc",
        filePath: "Sources/App/Handler.swift",
        line: 42,
        column: 5,
        complexity: 18,
        details: []
    )
    let resolvedViolation = FunctionComplexity(
        name: "simplifiedFunc",
        filePath: "Sources/App/Old.swift",
        line: 10,
        column: 5,
        complexity: 16,
        details: []
    )

    let fileDiff = FileDiffReport(
        path: "Sources/App/Handler.swift",
        beforeComplexity: 5,
        afterComplexity: 23,
        delta: 18,
        functionDeltas: [
            FunctionDelta(name: "simple", line: 10, beforeComplexity: 3, afterComplexity: 5, delta: 2),
            FunctionDelta(name: "complexFunc", line: 42, beforeComplexity: nil, afterComplexity: 18, delta: 18),
            FunctionDelta(name: "removed", line: 0, beforeComplexity: 2, afterComplexity: nil, delta: -2),
        ]
    )

    return DiffReport(
        changedFiles: [fileDiff],
        totalDelta: 18,
        warningThreshold: 15,
        errorThreshold: 25,
        newViolations: [newViolation],
        resolvedViolations: [resolvedViolation],
        elapsedSeconds: 0.5
    )
}

// MARK: - Text Format

@Test func diffTextContainsDelta() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.text.format(report, verbose: false)

    #expect(output.contains("delta: +18"))
    #expect(output.contains("1 changed file"))
}

@Test func diffTextShowsFunctionDeltas() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.text.format(report, verbose: false)

    #expect(output.contains("simple"))
    #expect(output.contains("3 -> 5"))
    #expect(output.contains("complexFunc"))
    #expect(output.contains("new"))
    #expect(output.contains("removed"))
    #expect(output.contains("deleted"))
}

@Test func diffTextShowsViolationCounts() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.text.format(report, verbose: false)

    #expect(output.contains("New violations: 1"))
    #expect(output.contains("Resolved violations: 1"))
}

// MARK: - JSON Format

@Test func diffJSONIsValid() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.json.format(report, verbose: false)

    let data = output.data(using: .utf8)!
    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(json != nil)
}

@Test func diffJSONContainsSummary() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.json.format(report, verbose: false)

    let data = output.data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    let summary = json["summary"] as! [String: Any]

    #expect(summary["totalDelta"] as? Int == 18)
    #expect(summary["changedFiles"] as? Int == 1)
    #expect(summary["newViolationCount"] as? Int == 1)
    #expect(summary["resolvedViolationCount"] as? Int == 1)
}

@Test func diffJSONContainsFiles() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.json.format(report, verbose: false)

    let data = output.data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    let files = json["files"] as! [[String: Any]]

    #expect(files.count == 1)
    let file = files[0]
    #expect(file["path"] as? String == "Sources/App/Handler.swift")
    #expect(file["delta"] as? Int == 18)

    let functions = file["functions"] as! [[String: Any]]
    #expect(functions.count == 3)
}

// MARK: - GitHub Format

@Test func diffGitHubOnlyNewViolations() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.github.format(report, verbose: false)

    #expect(output.contains("::warning"))
    #expect(output.contains("complexFunc"))
    // Should not contain resolved violations
    #expect(!output.contains("simplifiedFunc"))
}

@Test func diffGitHubEmptyForNoViolations() {
    let report = DiffReport(
        changedFiles: [],
        totalDelta: 0,
        warningThreshold: 15,
        errorThreshold: 25,
        newViolations: [],
        resolvedViolations: [],
        elapsedSeconds: 0.1
    )
    let output = OutputFormat.github.format(report, verbose: false)
    #expect(output.isEmpty)
}

// MARK: - Markdown Format

@Test func diffMarkdownContainsPRImpactHeader() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.markdown.format(report, verbose: false)

    #expect(output.contains("## Cognitive Complexity -- PR Impact"))
    #expect(output.contains("**Overall delta: +18**"))
}

@Test func diffMarkdownContainsNewViolationsTable() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.markdown.format(report, verbose: false)

    #expect(output.contains("### New violations (1)"))
    #expect(output.contains("| `Handler.swift` | `complexFunc` | 18 |"))
}

@Test func diffMarkdownContainsResolvedViolationsTable() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.markdown.format(report, verbose: false)

    #expect(output.contains("### Resolved violations (1)"))
    #expect(output.contains("simplifiedFunc"))
    #expect(output.contains(":white_check_mark:"))
}

@Test func diffMarkdownContainsChangedFunctionsTable() {
    let report = makeSampleDiffReport()
    let output = OutputFormat.markdown.format(report, verbose: false)

    #expect(output.contains("### Changed functions"))
    #expect(output.contains("| `Handler.swift` | `simple` | 3 | 5 | +2 |"))
    #expect(output.contains("| `Handler.swift` | `complexFunc` | -- | 18 | new |"))
    #expect(output.contains("| `Handler.swift` | `removed` | 2 | -- | deleted |"))
}

@Test func diffMarkdownEmptyReport() {
    let report = DiffReport(
        changedFiles: [],
        totalDelta: 0,
        warningThreshold: 15,
        errorThreshold: 25,
        newViolations: [],
        resolvedViolations: [],
        elapsedSeconds: 0.1
    )
    let output = OutputFormat.markdown.format(report, verbose: false)

    #expect(output.contains("## Cognitive Complexity -- PR Impact"))
    #expect(output.contains("**Overall delta: +0**"))
    #expect(!output.contains("### New violations"))
    #expect(!output.contains("### Changed functions"))
}
