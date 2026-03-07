import Foundation
import Testing
@testable import SCCLib

// MARK: - Defaults

@Test func defaultConfiguration() {
    let cfg = Configuration.default
    #expect(cfg.warningThreshold == 15)
    #expect(cfg.errorThreshold == 25)
    #expect(cfg.swiftuiAware == false)
    #expect(cfg.swiftuiContainers.contains("VStack"))
    #expect(cfg.excludePaths.contains(".build/**"))
    #expect(cfg.includePaths.isEmpty)
    #expect(cfg.scanSPMPackages == true)
}

// MARK: - YAML Parsing

@Test func parseFullConfig() throws {
    let yaml = """
    thresholds:
      warning: 10
      error: 20

    swiftui_aware: true

    swiftui_containers:
      - VStack
      - HStack
      - ZStack

    exclude_paths:
      - "**/Generated/**"
      - "**/*.generated.swift"

    include_paths:
      - "Sources/**"

    scan_spm_packages: false
    """
    let cfg = try Configuration.parse(yaml: yaml)
    #expect(cfg.warningThreshold == 10)
    #expect(cfg.errorThreshold == 20)
    #expect(cfg.swiftuiAware == true)
    #expect(cfg.swiftuiContainers == ["VStack", "HStack", "ZStack"])
    #expect(cfg.excludePaths == ["**/Generated/**", "**/*.generated.swift"])
    #expect(cfg.includePaths == ["Sources/**"])
    #expect(cfg.scanSPMPackages == false)
}

@Test func parseMissingKeysGetDefaults() throws {
    let yaml = """
    thresholds:
      warning: 5
    """
    let cfg = try Configuration.parse(yaml: yaml)
    #expect(cfg.warningThreshold == 5)
    #expect(cfg.errorThreshold == 25) // default
    #expect(cfg.swiftuiAware == false) // default
}

@Test func parseEmptyYaml() throws {
    let cfg = try Configuration.parse(yaml: "")
    #expect(cfg.warningThreshold == 15)
    #expect(cfg.errorThreshold == 25)
}

@Test func parseWithComments() throws {
    let yaml = """
    # This is a comment
    thresholds:
      warning: 12 # inline comment
      error: 30
    """
    let cfg = try Configuration.parse(yaml: yaml)
    #expect(cfg.warningThreshold == 12)
    #expect(cfg.errorThreshold == 30)
}

@Test func loadFromFixtureFile() throws {
    let path = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("test-config.yml")
        .path
    let cfg = try Configuration.load(from: path)
    #expect(cfg.warningThreshold == 10)
    #expect(cfg.errorThreshold == 20)
    #expect(cfg.swiftuiAware == true)
    #expect(cfg.swiftuiContainers == ["VStack", "HStack", "ZStack"])
}

// MARK: - CLI Merging

@Test func cliOverridesMerge() {
    let base = Configuration.default
    let merged = base.merging(
        cliWarningThreshold: 5,
        cliErrorThreshold: 10,
        cliExclude: ["**/Tests/**"]
    )
    #expect(merged.warningThreshold == 5)
    #expect(merged.errorThreshold == 10)
    #expect(merged.excludePaths.contains("**/Tests/**"))
    // Original excludes are preserved
    #expect(merged.excludePaths.contains(".build/**"))
}

@Test func cliOverridesNilDoesNotChange() {
    let base = Configuration(warningThreshold: 10, errorThreshold: 20)
    let merged = base.merging()
    #expect(merged.warningThreshold == 10)
    #expect(merged.errorThreshold == 20)
}
