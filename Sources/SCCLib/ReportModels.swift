//
// Swift Cognitive Complexity (scc)
//
// Copyright (c) 2026 Stanimir Karoserov.
// Licensed under the MIT License. See LICENSE file for details.
// SPDX-License-Identifier: MIT
//
public struct FileReport: Sendable, Equatable {
    public let path: String
    public let functions: [FunctionComplexity]

    public var fileComplexity: Int {
        functions.reduce(0) { $0 + $1.complexity }
    }

    public init(path: String, functions: [FunctionComplexity]) {
        self.path = path
        self.functions = functions
    }
}

public struct ProjectReport: Sendable {
    public let files: [FileReport]
    public let warningThreshold: Int
    public let errorThreshold: Int
    public let elapsedSeconds: Double

    public init(files: [FileReport], warningThreshold: Int, errorThreshold: Int, elapsedSeconds: Double) {
        self.files = files
        self.warningThreshold = warningThreshold
        self.errorThreshold = errorThreshold
        self.elapsedSeconds = elapsedSeconds
    }

    public var totalComplexity: Int {
        files.reduce(0) { $0 + $1.fileComplexity }
    }

    public var analyzedFileCount: Int {
        files.count
    }

    public var analyzedFunctionCount: Int {
        files.reduce(0) { $0 + $1.functions.count }
    }

    public var functionsAboveWarning: [FunctionComplexity] {
        files.flatMap { $0.functions }.filter { $0.complexity > warningThreshold }
    }

    public var functionsAboveError: [FunctionComplexity] {
        files.flatMap { $0.functions }.filter { $0.complexity > errorThreshold }
    }
}
