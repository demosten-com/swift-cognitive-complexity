import Foundation
import Testing
@testable import SCCLib

@Test func analyzeFixturesDirectory() async throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .path
    let cfg = Configuration(
        warningThreshold: 15,
        errorThreshold: 25,
        excludePaths: []
    )
    let analyzer = ProjectAnalyzer(configuration: cfg)
    let report = try await analyzer.analyze(paths: [fixturesDir])

    #expect(report.analyzedFileCount >= 5)
    #expect(report.analyzedFunctionCount >= 5)
    #expect(report.totalComplexity > 0)
    #expect(report.elapsedSeconds >= 0)
}

@Test func analyzeFixturesKnownScores() async throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .path
    let cfg = Configuration(excludePaths: [])
    let analyzer = ProjectAnalyzer(configuration: cfg)
    let report = try await analyzer.analyze(paths: [fixturesDir])

    let allFunctions = report.files.flatMap { $0.functions }
    let sumOfPrimes = allFunctions.first { $0.name == "sumOfPrimes" }
    let getWords = allFunctions.first { $0.name == "getWords" }
    let myMethod = allFunctions.first { $0.name == "myMethod" }
    let overridden = allFunctions.first { $0.name == "overriddenSymbolFrom" }

    #expect(sumOfPrimes?.complexity == 7)
    #expect(getWords?.complexity == 1)
    #expect(myMethod?.complexity == 9)
    #expect(overridden?.complexity == 19)
}

@Test func analyzeSingleFile() async throws {
    let filePath = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("sumOfPrimes.swift")
        .path
    let cfg = Configuration(excludePaths: [])
    let analyzer = ProjectAnalyzer(configuration: cfg)
    let report = try await analyzer.analyze(paths: [filePath])

    #expect(report.analyzedFileCount == 1)
    #expect(report.files[0].functions.count >= 1)
}

@Test func reportThresholdFiltering() async throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .path
    let cfg = Configuration(
        warningThreshold: 5,
        errorThreshold: 10,
        excludePaths: []
    )
    let analyzer = ProjectAnalyzer(configuration: cfg)
    let report = try await analyzer.analyze(paths: [fixturesDir])

    // overriddenSymbolFrom scores 19, should be above both thresholds
    #expect(report.functionsAboveWarning.contains(where: { $0.name == "overriddenSymbolFrom" }))
    #expect(report.functionsAboveError.contains(where: { $0.name == "overriddenSymbolFrom" }))
}

@Test func analyzeReturnsRelativePaths() async throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .path
    let cfg = Configuration(excludePaths: [])
    let analyzer = ProjectAnalyzer(configuration: cfg)
    let report = try await analyzer.analyze(paths: [fixturesDir])

    for file in report.files {
        #expect(!file.path.hasPrefix("/"), "Path should be relative: \(file.path)")
        for fn in file.functions {
            #expect(!fn.filePath.hasPrefix("/"), "Function filePath should be relative: \(fn.filePath)")
        }
    }
}

@Test func analyzeFileReturnsNilForInvalidPath() {
    let analyzer = ProjectAnalyzer(configuration: .default)
    let result = analyzer.analyzeFile(at: "/nonexistent/file.swift")
    #expect(result == nil)
}

// MARK: - Error Recovery

@Test func fileWithSyntaxErrorsDoesNotCrash() {
    let source = """
    func f() {
        if true {
        // missing closing braces
    """
    let analyzer = ProjectAnalyzer(configuration: .default)
    let report = analyzer.analyzeSource(source, filePath: "broken.swift")
    // SwiftSyntax recovers from syntax errors — should not crash
    #expect(report.path == "broken.swift")
}

@Test func emptyFileReturnsNoFunctions() {
    let analyzer = ProjectAnalyzer(configuration: .default)
    let report = analyzer.analyzeSource("", filePath: "empty.swift")
    #expect(report.functions.isEmpty)
}

@Test func fileWithOnlyCommentsReturnsNoFunctions() {
    let source = """
    // This file has no code
    /* Just comments */
    """
    let analyzer = ProjectAnalyzer(configuration: .default)
    let report = analyzer.analyzeSource(source, filePath: "comments.swift")
    #expect(report.functions.isEmpty)
}

@Test func oversizedFileIsSkipped() throws {
    let tmpDir = NSTemporaryDirectory() + "scc-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let largePath = tmpDir + "/large.swift"
    // Create a file larger than 100 bytes (using a tiny max for testing)
    let content = String(repeating: "// padding\n", count: 20)
    try content.write(toFile: largePath, atomically: true, encoding: .utf8)

    let cfg = Configuration(excludePaths: [], maxFileSize: 100)
    let analyzer = ProjectAnalyzer(configuration: cfg)
    let result = analyzer.analyzeFile(at: largePath)
    #expect(result == nil)
}
