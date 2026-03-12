//
// Swift Cognitive Complexity (scc)
//
// Copyright (c) 2026 Stanimir Karoserov.
// Licensed under the MIT License. See LICENSE file for details.
// SPDX-License-Identifier: MIT
//
import XCTest
import Foundation
@testable import SCCLib

final class OutputFormatTests: XCTestCase {

    // MARK: - Test Fixture

    private func makeTestReport() -> ProjectReport {
        ProjectReport(
            files: [
                FileReport(path: "Sources/Foo.swift", functions: [
                    FunctionComplexity(
                        name: "simple()",
                        filePath: "Sources/Foo.swift",
                        line: 10, column: 5,
                        complexity: 3,
                        details: [
                            ComplexityIncrement(line: 11, description: "if", increment: 1),
                            ComplexityIncrement(line: 12, description: "for (nesting=1)", increment: 2),
                        ]
                    ),
                    FunctionComplexity(
                        name: "complex(_:)",
                        filePath: "Sources/Foo.swift",
                        line: 30, column: 5,
                        complexity: 18,
                        details: [
                            ComplexityIncrement(line: 31, description: "if", increment: 1),
                            ComplexityIncrement(line: 33, description: "for (nesting=1)", increment: 2),
                            ComplexityIncrement(line: 35, description: "if (nesting=2)", increment: 3),
                            ComplexityIncrement(line: 40, description: "else", increment: 1),
                            ComplexityIncrement(line: 42, description: "switch (nesting=2)", increment: 3),
                            ComplexityIncrement(line: 50, description: "while (nesting=1)", increment: 2),
                            ComplexityIncrement(line: 52, description: "if (nesting=2)", increment: 3),
                            ComplexityIncrement(line: 55, description: "&&", increment: 1),
                            ComplexityIncrement(line: 58, description: "guard (nesting=1)", increment: 2),
                        ]
                    ),
                    FunctionComplexity(
                        name: "veryComplex()",
                        filePath: "Sources/Foo.swift",
                        line: 60, column: 5,
                        complexity: 30,
                        details: []
                    ),
                ]),
            ],
            warningThreshold: 15,
            errorThreshold: 25,
            elapsedSeconds: 1.5
        )
    }

    private func makeEmptyReport() -> ProjectReport {
        ProjectReport(
            files: [],
            warningThreshold: 15,
            errorThreshold: 25,
            elapsedSeconds: 0.01
        )
    }

    // MARK: - Text Format

    func testTextContainsFileAndFunctions() {
        let output = OutputFormat.text.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("Sources/Foo.swift"))
        XCTAssertTrue(output.contains("simple()"))
        XCTAssertTrue(output.contains("complex(_:)"))
        XCTAssertTrue(output.contains("veryComplex()"))
    }

    func testTextShowsThresholdIndicators() {
        let output = OutputFormat.text.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("exceeds threshold (15)"), "Should show warning for complexity 18")
        XCTAssertTrue(output.contains("exceeds error threshold (25)"), "Should show error for complexity 30")
    }

    func testTextShowsSummary() {
        let output = OutputFormat.text.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("1 files, 3 functions analyzed"))
        XCTAssertTrue(output.contains("Total project complexity:"))
    }

    func testTextVerboseShowsDetails() {
        let output = OutputFormat.text.format(makeTestReport(), verbose: true)
        XCTAssertTrue(output.contains("line 11: if"))
        XCTAssertTrue(output.contains("line 12: for (nesting=1)"))
    }

    func testTextNonVerboseHidesDetails() {
        let output = OutputFormat.text.format(makeTestReport(), verbose: false)
        XCTAssertFalse(output.contains("line 11: if"))
    }

    // MARK: - JSON Format

    func testJSONIsValid() throws {
        let output = OutputFormat.json.format(makeTestReport(), verbose: false)
        let data = output.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(obj is [String: Any])
    }

    func testJSONSummary() throws {
        let output = OutputFormat.json.format(makeTestReport(), verbose: false)
        let data = output.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let summary = obj["summary"] as! [String: Any]

        XCTAssertEqual(summary["totalFiles"] as? Int, 1)
        XCTAssertEqual(summary["totalFunctions"] as? Int, 3)
        XCTAssertEqual(summary["totalComplexity"] as? Int, 51)
        XCTAssertEqual(summary["warningCount"] as? Int, 2)
        XCTAssertEqual(summary["errorCount"] as? Int, 1)
        XCTAssertEqual(summary["elapsedMs"] as? Int, 1500)
    }

    func testJSONStatusValues() throws {
        let output = OutputFormat.json.format(makeTestReport(), verbose: false)
        let data = output.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let files = obj["files"] as! [[String: Any]]
        let functions = files[0]["functions"] as! [[String: Any]]

        XCTAssertEqual(functions[0]["status"] as? String, "ok")
        XCTAssertEqual(functions[1]["status"] as? String, "warning")
        XCTAssertEqual(functions[2]["status"] as? String, "error")
    }

    func testJSONIncrementsAlwaysPresent() throws {
        let output = OutputFormat.json.format(makeTestReport(), verbose: false)
        let data = output.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let files = obj["files"] as! [[String: Any]]
        let functions = files[0]["functions"] as! [[String: Any]]

        // simple() has 2 increments
        let increments = functions[0]["increments"] as! [[String: Any]]
        XCTAssertEqual(increments.count, 2)

        // veryComplex() has 0 increments but array should still exist
        let emptyIncrements = functions[2]["increments"] as! [[String: Any]]
        XCTAssertEqual(emptyIncrements.count, 0)
    }

    // MARK: - GitHub Format

    func testGitHubWarningLine() {
        let output = OutputFormat.github.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("::warning file=Sources/Foo.swift,line=30,col=5,title=Cognitive Complexity::Function complex(_:) has cognitive complexity 18 (threshold: 15)"))
    }

    func testGitHubErrorLine() {
        let output = OutputFormat.github.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("::error file=Sources/Foo.swift,line=60,col=5,title=Cognitive Complexity::Function veryComplex() has cognitive complexity 30 (threshold: 25)"))
    }

    func testGitHubNoOutputForOKFunctions() {
        let output = OutputFormat.github.format(makeTestReport(), verbose: false)
        XCTAssertFalse(output.contains("simple()"))
    }

    // MARK: - Markdown Format

    func testMarkdownHeading() {
        let output = OutputFormat.markdown.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("## Cognitive Complexity Report"))
    }

    func testMarkdownTableHeader() {
        let output = OutputFormat.markdown.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("| File | Function | Line | Complexity | Status |"))
        XCTAssertTrue(output.contains("|------|----------|------|------------|--------|"))
    }

    func testMarkdownOnlyViolationsInTable() {
        let output = OutputFormat.markdown.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("`complex(_:)`"))
        XCTAssertTrue(output.contains("`veryComplex()`"))
        XCTAssertFalse(output.contains("`simple()`"))
    }

    func testMarkdownSummaryCounts() {
        let output = OutputFormat.markdown.format(makeTestReport(), verbose: false)
        XCTAssertTrue(output.contains("**2 functions** exceed the warning threshold"))
        XCTAssertTrue(output.contains("**1 function** exceed the error threshold"))
    }

    // MARK: - Violations Only

    func testTextViolationsOnlyExcludesOKFunctions() {
        let output = OutputFormat.text.format(makeTestReport(), verbose: false, violationsOnly: true)
        XCTAssertFalse(output.contains("simple()"), "Should not show function below warning threshold")
    }

    func testTextViolationsOnlyShowsWarningsAndErrors() {
        let output = OutputFormat.text.format(makeTestReport(), verbose: false, violationsOnly: true)
        XCTAssertTrue(output.contains("complex(_:)"), "Should show function exceeding warning threshold")
        XCTAssertTrue(output.contains("veryComplex()"), "Should show function exceeding error threshold")
    }

    func testTextViolationsOnlySkipsCleanFiles() {
        let report = ProjectReport(
            files: [
                FileReport(path: "Sources/Clean.swift", functions: [
                    FunctionComplexity(name: "clean()", filePath: "Sources/Clean.swift", line: 1, column: 1, complexity: 3, details: []),
                ]),
                FileReport(path: "Sources/Dirty.swift", functions: [
                    FunctionComplexity(name: "dirty()", filePath: "Sources/Dirty.swift", line: 1, column: 1, complexity: 20, details: []),
                ]),
            ],
            warningThreshold: 15, errorThreshold: 25, elapsedSeconds: 0.1
        )
        let output = OutputFormat.text.format(report, verbose: false, violationsOnly: true)
        XCTAssertFalse(output.contains("Clean.swift"), "Should skip files with no violations")
        XCTAssertTrue(output.contains("Dirty.swift"), "Should show files with violations")
    }

    func testTextViolationsOnlyStillShowsSummary() {
        let output = OutputFormat.text.format(makeTestReport(), verbose: false, violationsOnly: true)
        XCTAssertTrue(output.contains("1 files, 3 functions analyzed"), "Summary should still show full counts")
    }

    func testJSONViolationsOnlyFiltersFiles() throws {
        let output = OutputFormat.json.format(makeTestReport(), verbose: false, violationsOnly: true)
        let data = output.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let files = obj["files"] as! [[String: Any]]
        let functions = files[0]["functions"] as! [[String: Any]]

        // Should only contain warning and error functions, not "simple()"
        XCTAssertEqual(functions.count, 2)
        XCTAssertEqual(functions[0]["name"] as? String, "complex(_:)")
        XCTAssertEqual(functions[1]["name"] as? String, "veryComplex()")

        // Summary should still have full counts
        let summary = obj["summary"] as! [String: Any]
        XCTAssertEqual(summary["totalFunctions"] as? Int, 3)
    }

    // MARK: - Empty Report

    func testTextEmptyReport() {
        let output = OutputFormat.text.format(makeEmptyReport(), verbose: false)
        XCTAssertTrue(output.contains("0 files, 0 functions analyzed"))
    }

    func testJSONEmptyReport() throws {
        let output = OutputFormat.json.format(makeEmptyReport(), verbose: false)
        let data = output.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let summary = obj["summary"] as! [String: Any]
        XCTAssertEqual(summary["totalFiles"] as? Int, 0)
        XCTAssertEqual(summary["totalFunctions"] as? Int, 0)
    }

    func testGitHubEmptyReport() {
        let output = OutputFormat.github.format(makeEmptyReport(), verbose: false)
        XCTAssertTrue(output.isEmpty)
    }

    func testMarkdownEmptyReport() {
        let output = OutputFormat.markdown.format(makeEmptyReport(), verbose: false)
        XCTAssertTrue(output.contains("No functions exceed"))
    }
}
