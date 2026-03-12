//
// Swift Cognitive Complexity (scc)
//
// Copyright (c) 2026 Stanimir Karoserov.
// Licensed under the MIT License. See LICENSE file for details.
// SPDX-License-Identifier: MIT
//
import Foundation

public struct Configuration: Sendable, Equatable {
    public var warningThreshold: Int
    public var errorThreshold: Int
    public var swiftuiAware: Bool
    public var swiftuiContainers: [String]
    public var excludePaths: [String]
    public var includePaths: [String]
    public var maxFileSize: Int
    public var scanSPMPackages: Bool
    public var spmPackagePaths: [String]

    public static let `default` = Configuration(
        warningThreshold: 15,
        errorThreshold: 25,
        swiftuiAware: false,
        swiftuiContainers: [
            "VStack", "HStack", "ZStack",
            "LazyVStack", "LazyHStack", "LazyVGrid", "LazyHGrid",
            "List", "ScrollView", "Group", "Section",
            "NavigationStack", "NavigationSplitView", "TabView",
            "Form", "Sheet", "Alert", "Menu", "Overlay",
        ],
        excludePaths: [
            "**/Generated/**",
            "**/Mocks/**",
            "**/*.generated.swift",
            ".build/**",
        ],
        includePaths: [],
        maxFileSize: 512_000,
        scanSPMPackages: true,
        spmPackagePaths: []
    )

    public init(
        warningThreshold: Int = 15,
        errorThreshold: Int = 25,
        swiftuiAware: Bool = false,
        swiftuiContainers: [String] = Configuration.default.swiftuiContainers,
        excludePaths: [String] = Configuration.default.excludePaths,
        includePaths: [String] = [],
        maxFileSize: Int = 512_000,
        scanSPMPackages: Bool = true,
        spmPackagePaths: [String] = []
    ) {
        self.warningThreshold = warningThreshold
        self.errorThreshold = errorThreshold
        self.swiftuiAware = swiftuiAware
        self.swiftuiContainers = swiftuiContainers
        self.excludePaths = excludePaths
        self.includePaths = includePaths
        self.maxFileSize = maxFileSize
        self.scanSPMPackages = scanSPMPackages
        self.spmPackagePaths = spmPackagePaths
    }

    public static func load(from path: String) throws -> Configuration {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(yaml: content)
    }

    public static func loadIfExists(from path: String) -> Configuration {
        guard FileManager.default.fileExists(atPath: path) else {
            return .default
        }
        do {
            return try load(from: path)
        } catch {
            FileHandle.standardError.write(Data("Warning: Failed to parse config file '\(path)': \(error). Using defaults.\n".utf8))
            return .default
        }
    }

    public func merging(
        cliWarningThreshold: Int? = nil,
        cliErrorThreshold: Int? = nil,
        cliExclude: [String] = [],
        cliInclude: [String] = [],
        cliSwiftuiAware: Bool? = nil,
        cliMaxFileSize: Int? = nil
    ) -> Configuration {
        var merged = self
        if let w = cliWarningThreshold { merged.warningThreshold = w }
        if let e = cliErrorThreshold { merged.errorThreshold = e }
        if !cliExclude.isEmpty { merged.excludePaths = excludePaths + cliExclude }
        if !cliInclude.isEmpty { merged.includePaths = cliInclude }
        if let s = cliSwiftuiAware { merged.swiftuiAware = s }
        if let m = cliMaxFileSize { merged.maxFileSize = m }
        return merged
    }

    // MARK: - YAML Parser

    private struct YAMLParserState {
        var currentSection: String? = nil
        var currentList: [String]? = nil
        var currentListKey: String? = nil

        mutating func flushList(to config: inout Configuration) {
            if let key = currentListKey, let list = currentList {
                applyList(key: key, list: list, to: &config)
            }
            currentList = nil
            currentListKey = nil
        }
    }

    static func parse(yaml content: String) throws -> Configuration {
        var config = Configuration.default
        var state = YAMLParserState()

        for rawLine in content.components(separatedBy: .newlines) {
            let commentFree = stripComment(rawLine)
            let trimmed = commentFree.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let indent = commentFree.prefix(while: { $0 == " " }).count
            processLine(trimmed: trimmed, indent: indent, config: &config, state: &state)
        }

        state.flushList(to: &config)
        return config
    }

    private static func processLine(trimmed: String, indent: Int, config: inout Configuration, state: inout YAMLParserState) {
        // List item
        if trimmed.hasPrefix("- ") {
            let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if state.currentList != nil {
                state.currentList?.append(value)
            }
            return
        }

        // Key-value or section header
        guard let colonIndex = trimmed.firstIndex(of: ":") else { return }
        let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let valueStr = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

        // If there's a pending list, flush it
        if indent == 0 || (indent > 0 && !valueStr.isEmpty) {
            state.flushList(to: &config)
        }

        applyKeyValue(key: key, valueStr: valueStr, indent: indent, config: &config, state: &state)
    }

    private static func applyKeyValue(key: String, valueStr: String, indent: Int, config: inout Configuration, state: inout YAMLParserState) {
        if valueStr.isEmpty {
            // Section header or list start
            if indent == 0 {
                state.currentSection = key
                if ["exclude_paths", "include_paths", "swiftui_containers", "spm_package_paths"].contains(key) {
                    state.currentList = []
                    state.currentListKey = key
                    state.currentSection = nil
                }
            } else if state.currentSection == "thresholds" {
                // Shouldn't happen for thresholds, but handle gracefully
            } else {
                // Nested list under a section
                state.currentList = []
                state.currentListKey = key
            }
        } else {
            // Scalar value
            if indent == 0 {
                applyScalar(key: key, value: valueStr, to: &config)
                state.currentSection = nil
            } else if state.currentSection == "thresholds" {
                applyThresholdScalar(key: key, value: valueStr, to: &config)
            }
        }
    }

    private static func applyThresholdScalar(key: String, value: String, to config: inout Configuration) {
        if key == "warning", let val = Int(value) {
            config.warningThreshold = val
        } else if key == "error", let val = Int(value) {
            config.errorThreshold = val
        }
    }

    private static func stripComment(_ line: String) -> String {
        // Naive comment stripping — doesn't handle # inside quotes
        guard let hashIndex = line.firstIndex(of: "#") else { return line }
        // Only strip if # is preceded by whitespace or is at line start
        if hashIndex == line.startIndex { return "" }
        let before = line[line.index(before: hashIndex)]
        if before == " " || before == "\t" {
            return String(line[..<hashIndex])
        }
        return line
    }

    private static func applyScalar(key: String, value: String, to config: inout Configuration) {
        let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        switch key {
        case "swiftui_aware":
            config.swiftuiAware = cleaned == "true"
        case "scan_spm_packages":
            config.scanSPMPackages = cleaned == "true"
        case "max_file_size":
            if let val = Int(cleaned) {
                config.maxFileSize = val
            }
        default:
            break
        }
    }

    private static func applyList(key: String, list: [String], to config: inout Configuration) {
        switch key {
        case "exclude_paths":
            config.excludePaths = list
        case "include_paths":
            config.includePaths = list
        case "swiftui_containers":
            config.swiftuiContainers = list
        case "spm_package_paths":
            config.spmPackagePaths = list
        default:
            break
        }
    }
}
