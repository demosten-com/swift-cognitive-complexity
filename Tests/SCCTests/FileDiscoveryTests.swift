import Foundation
import Testing
@testable import SCCLib

// MARK: - Glob Matching

@Test func matchesSimpleGlob() {
    #expect(FileDiscovery.matchesGlob(path: "foo.swift", pattern: "*.swift"))
    #expect(!FileDiscovery.matchesGlob(path: "foo.txt", pattern: "*.swift"))
}

@Test func matchesDoubleStarGlob() {
    #expect(FileDiscovery.matchesGlob(path: "Sources/Foo/Bar.swift", pattern: "**/*.swift"))
    #expect(FileDiscovery.matchesGlob(path: "a/b/c/d.swift", pattern: "**/*.swift"))
    #expect(!FileDiscovery.matchesGlob(path: "a/b/c/d.txt", pattern: "**/*.swift"))
}

@Test func matchesPrefixDoubleStarGlob() {
    #expect(FileDiscovery.matchesGlob(path: "Sources/Foo/Bar.swift", pattern: "Sources/**"))
    #expect(!FileDiscovery.matchesGlob(path: "Tests/Foo/Bar.swift", pattern: "Sources/**"))
}

@Test func matchesDirectoryExcludePattern() {
    #expect(FileDiscovery.matchesGlob(path: "path/Generated/File.swift", pattern: "**/Generated/**"))
    #expect(!FileDiscovery.matchesGlob(path: "path/Source/File.swift", pattern: "**/Generated/**"))
}

// MARK: - File Discovery

@Test func discoversSingleFile() throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
    let singleFile = fixturesDir.appendingPathComponent("basic.swift").path
    let discovery = FileDiscovery()
    let files = try discovery.discoverFiles(in: [singleFile])
    #expect(files.count == 1)
    #expect(files[0].hasSuffix("basic.swift"))
}

@Test func discoversDirectoryFiles() throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .path
    let discovery = FileDiscovery()
    let files = try discovery.discoverFiles(in: [fixturesDir])
    // Should find at least the known fixture files
    #expect(files.count >= 5) // basic, sumOfPrimes, getWords, myMethod, overriddenSymbolFrom
    #expect(files.allSatisfy { $0.hasSuffix(".swift") })
}

@Test func excludePatternFiltersFiles() throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .path
    let discovery = FileDiscovery(excludePaths: ["**/basic*"])
    let files = try discovery.discoverFiles(in: [fixturesDir])
    #expect(!files.contains(where: { $0.contains("basic") }))
}

@Test func includePatternFiltersFiles() throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .path
    let discovery = FileDiscovery(includePaths: ["**/basic*"])
    let files = try discovery.discoverFiles(in: [fixturesDir])
    #expect(files.count == 1)
    #expect(files[0].contains("basic"))
}

@Test func nonExistentPathThrows() {
    let discovery = FileDiscovery()
    #expect(throws: FileDiscoveryError.self) {
        try discovery.discoverFiles(in: ["/nonexistent/path/to/nowhere"])
    }
}

@Test func nonSwiftFilesAreSkipped() throws {
    let fixturesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .path
    let discovery = FileDiscovery()
    let files = try discovery.discoverFiles(in: [fixturesDir])
    // test-config.yml should not be in the results
    #expect(!files.contains(where: { $0.hasSuffix(".yml") }))
}
