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

// MARK: - BaselineLoader Tests

@Test func baselineLoadFromJSON() throws {
    let json = """
    {
        "files": [
            {
                "path": "Sources/Foo.swift",
                "functions": [
                    { "name": "bar", "line": 10, "column": 5, "complexity": 20, "status": "warning", "increments": [] }
                ]
            }
        ],
        "summary": { "totalFiles": 1, "totalFunctions": 1, "totalComplexity": 20, "warningThreshold": 15, "errorThreshold": 25, "warningCount": 1, "errorCount": 0, "elapsedMs": 100 }
    }
    """
    let tmpFile = NSTemporaryDirectory() + "baseline-test-\(UUID().uuidString).json"
    try json.write(toFile: tmpFile, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(atPath: tmpFile) }

    let baseline = try BaselineLoader.load(from: tmpFile)
    #expect(baseline.files.count == 1)
    #expect(baseline.files[0].functions[0].name == "bar")
    #expect(baseline.files[0].functions[0].complexity == 20)
}

@Test func baselineFilterSuppressesPreExistingViolation() {
    let baseline = BaselineReport(files: [
        .init(path: "Foo.swift", functions: [
            .init(name: "complex", complexity: 30)
        ])
    ])

    let report = ProjectReport(
        files: [
            FileReport(path: "Foo.swift", functions: [
                FunctionComplexity(name: "complex", filePath: "Foo.swift", line: 1, column: 1, complexity: 30, details: [])
            ])
        ],
        warningThreshold: 15,
        errorThreshold: 25,
        elapsedSeconds: 0.1
    )

    let newViolations = BaselineLoader.filterNewViolations(report: report, baseline: baseline, threshold: 25)
    #expect(newViolations.isEmpty)
}

@Test func baselineFilterReportsNewViolation() {
    let baseline = BaselineReport(files: [
        .init(path: "Foo.swift", functions: [
            .init(name: "simple", complexity: 5)
        ])
    ])

    let report = ProjectReport(
        files: [
            FileReport(path: "Foo.swift", functions: [
                FunctionComplexity(name: "simple", filePath: "Foo.swift", line: 1, column: 1, complexity: 30, details: [])
            ])
        ],
        warningThreshold: 15,
        errorThreshold: 25,
        elapsedSeconds: 0.1
    )

    let newViolations = BaselineLoader.filterNewViolations(report: report, baseline: baseline, threshold: 25)
    #expect(newViolations.count == 1)
    #expect(newViolations[0].name == "simple")
}

@Test func baselineFilterReportsNewFunction() {
    let baseline = BaselineReport(files: [])

    let report = ProjectReport(
        files: [
            FileReport(path: "Foo.swift", functions: [
                FunctionComplexity(name: "brandNew", filePath: "Foo.swift", line: 1, column: 1, complexity: 30, details: [])
            ])
        ],
        warningThreshold: 15,
        errorThreshold: 25,
        elapsedSeconds: 0.1
    )

    let newViolations = BaselineLoader.filterNewViolations(report: report, baseline: baseline, threshold: 25)
    #expect(newViolations.count == 1)
    #expect(newViolations[0].name == "brandNew")
}

@Test func baselineMalformedJSONThrows() {
    let tmpFile = NSTemporaryDirectory() + "baseline-bad-\(UUID().uuidString).json"
    try! "{ invalid json".write(toFile: tmpFile, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(atPath: tmpFile) }

    #expect(throws: (any Error).self) {
        _ = try BaselineLoader.load(from: tmpFile)
    }
}
