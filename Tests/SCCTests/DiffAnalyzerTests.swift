import Foundation
import Testing
@testable import SCCLib

// MARK: - Mock Git Operations

struct MockGitOperations: GitOperations, Sendable {
    let root: String
    let changedFiles: [String]
    let fileContents: [String: String] // "ref:path" -> content

    init(root: String = "/repo", changedFiles: [String] = [], fileContents: [String: String] = [:]) {
        self.root = root
        self.changedFiles = changedFiles
        self.fileContents = fileContents
    }

    func changedSwiftFiles(baseRef: String) throws -> [String] {
        changedFiles
    }

    func fileContent(at path: String, ref: String) throws -> String? {
        fileContents["\(ref):\(path)"]
    }

    func repositoryRoot() throws -> String {
        root
    }
}

// MARK: - Tests

@Test func emptyChangedFilesProducesEmptyReport() async throws {
    let git = MockGitOperations()
    let cfg = Configuration(excludePaths: [])
    let analyzer = DiffAnalyzer(configuration: cfg, gitOperations: git)

    let report = try await analyzer.analyze(baseRef: "main", changedFiles: [])

    #expect(report.changedFiles.isEmpty)
    #expect(report.totalDelta == 0)
    #expect(report.newViolations.isEmpty)
    #expect(report.resolvedViolations.isEmpty)
}

@Test func newFileAllFunctionsNew() async throws {
    let tmpDir = NSTemporaryDirectory() + "scc-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let source = """
    func simple(x: Int) -> Int {
        if x > 0 {
            return x
        }
        return 0
    }
    """
    try source.write(toFile: tmpDir + "/new.swift", atomically: true, encoding: .utf8)

    // No base content = new file
    let git = MockGitOperations(root: tmpDir, fileContents: [:])
    let cfg = Configuration(excludePaths: [])
    let analyzer = DiffAnalyzer(configuration: cfg, gitOperations: git)

    let report = try await analyzer.analyze(baseRef: "main", changedFiles: ["new.swift"])

    #expect(report.changedFiles.count == 1)
    let file = report.changedFiles[0]
    #expect(file.beforeComplexity == 0)
    #expect(file.afterComplexity > 0)

    let fd = file.functionDeltas.first { $0.name == "simple" }
    #expect(fd != nil)
    #expect(fd?.beforeComplexity == nil)
    #expect(fd?.afterComplexity == 1) // single if = 1
}

@Test func modifiedFileDeltaComputed() async throws {
    let tmpDir = NSTemporaryDirectory() + "scc-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let beforeSource = """
    func example() {
        if true { }
    }
    """

    let afterSource = """
    func example() {
        if true {
            if true { }
        }
    }
    """
    try afterSource.write(toFile: tmpDir + "/file.swift", atomically: true, encoding: .utf8)

    let git = MockGitOperations(
        root: tmpDir,
        fileContents: ["main:file.swift": beforeSource]
    )
    let cfg = Configuration(excludePaths: [])
    let analyzer = DiffAnalyzer(configuration: cfg, gitOperations: git)

    let report = try await analyzer.analyze(baseRef: "main", changedFiles: ["file.swift"])

    #expect(report.changedFiles.count == 1)
    let file = report.changedFiles[0]
    #expect(file.beforeComplexity == 1) // single if
    #expect(file.afterComplexity == 3)  // if(+1) + nested if(+1 + nesting 1 = +2) = 3
    #expect(file.delta == 2)
    #expect(report.totalDelta == 2)
}

@Test func deletedFunctionDetected() async throws {
    let tmpDir = NSTemporaryDirectory() + "scc-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let beforeSource = """
    func kept() {
        if true { }
    }
    func removed() {
        if true { }
    }
    """

    let afterSource = """
    func kept() {
        if true { }
    }
    """
    try afterSource.write(toFile: tmpDir + "/file.swift", atomically: true, encoding: .utf8)

    let git = MockGitOperations(
        root: tmpDir,
        fileContents: ["main:file.swift": beforeSource]
    )
    let cfg = Configuration(excludePaths: [])
    let analyzer = DiffAnalyzer(configuration: cfg, gitOperations: git)

    let report = try await analyzer.analyze(baseRef: "main", changedFiles: ["file.swift"])

    let file = report.changedFiles[0]
    let deleted = file.functionDeltas.first { $0.name == "removed" }
    #expect(deleted != nil)
    #expect(deleted?.beforeComplexity == 1)
    #expect(deleted?.afterComplexity == nil)
    #expect(deleted?.delta == -1)
}

@Test func newViolationDetected() async throws {
    let tmpDir = NSTemporaryDirectory() + "scc-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    // Before: simple function below threshold
    let beforeSource = """
    func complex() {
        if true { }
    }
    """

    // After: complex function above threshold (with low threshold for test)
    let afterSource = """
    func complex() {
        if true {
            if true {
                if true { }
            }
        }
    }
    """
    try afterSource.write(toFile: tmpDir + "/file.swift", atomically: true, encoding: .utf8)

    let git = MockGitOperations(
        root: tmpDir,
        fileContents: ["main:file.swift": beforeSource]
    )
    // Set warning threshold to 3 so the after version exceeds it
    let cfg = Configuration(warningThreshold: 3, errorThreshold: 10, excludePaths: [])
    let analyzer = DiffAnalyzer(configuration: cfg, gitOperations: git)

    let report = try await analyzer.analyze(baseRef: "main", changedFiles: ["file.swift"])

    // After: if(+1) + if(+2) + if(+3) = 6 > threshold 3
    #expect(!report.newViolations.isEmpty)
    #expect(report.newViolations.first?.name == "complex")
}

@Test func resolvedViolationDetected() async throws {
    let tmpDir = NSTemporaryDirectory() + "scc-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    // Before: complex function above threshold
    let beforeSource = """
    func complex() {
        if true {
            if true {
                if true { }
            }
        }
    }
    """

    // After: simplified below threshold
    let afterSource = """
    func complex() {
        if true { }
    }
    """
    try afterSource.write(toFile: tmpDir + "/file.swift", atomically: true, encoding: .utf8)

    let git = MockGitOperations(
        root: tmpDir,
        fileContents: ["main:file.swift": beforeSource]
    )
    let cfg = Configuration(warningThreshold: 3, errorThreshold: 10, excludePaths: [])
    let analyzer = DiffAnalyzer(configuration: cfg, gitOperations: git)

    let report = try await analyzer.analyze(baseRef: "main", changedFiles: ["file.swift"])

    #expect(!report.resolvedViolations.isEmpty)
    #expect(report.resolvedViolations.first?.name == "complex")
    #expect(report.newViolations.isEmpty)
}

@Test func excludeFilterApplied() async throws {
    let tmpDir = NSTemporaryDirectory() + "scc-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let source = "func foo() { }"
    try source.write(toFile: tmpDir + "/file.swift", atomically: true, encoding: .utf8)

    let git = MockGitOperations(
        root: tmpDir,
        changedFiles: ["file.swift", "Generated/auto.swift"]
    )
    let cfg = Configuration(excludePaths: ["Generated/**"])
    let analyzer = DiffAnalyzer(configuration: cfg, gitOperations: git)

    // Use nil changedFiles to trigger git detection
    let report = try await analyzer.analyze(baseRef: "main")

    // Generated/auto.swift should be excluded
    #expect(report.changedFiles.count == 1)
    #expect(report.changedFiles[0].path == "file.swift")
}

@Test func autoDetectsChangedFiles() async throws {
    let tmpDir = NSTemporaryDirectory() + "scc-test-\(UUID().uuidString)"
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let source = "func foo() { }"
    try source.write(toFile: tmpDir + "/a.swift", atomically: true, encoding: .utf8)
    try source.write(toFile: tmpDir + "/b.swift", atomically: true, encoding: .utf8)

    let git = MockGitOperations(
        root: tmpDir,
        changedFiles: ["a.swift", "b.swift"]
    )
    let cfg = Configuration(excludePaths: [])
    let analyzer = DiffAnalyzer(configuration: cfg, gitOperations: git)

    let report = try await analyzer.analyze(baseRef: "main")

    #expect(report.changedFiles.count == 2)
}
