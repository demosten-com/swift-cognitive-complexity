//
// Swift Cognitive Complexity (scc)
//
// Copyright (c) 2026 Stanimir Karoserov.
// Licensed under the MIT License. See LICENSE file for details.
// SPDX-License-Identifier: MIT
//
import Foundation

public struct BaselineReport: Decodable, Sendable {
    public let files: [BaselineFile]

    public struct BaselineFile: Decodable, Sendable {
        public let path: String
        public let functions: [BaselineFunction]
    }

    public struct BaselineFunction: Decodable, Sendable {
        public let name: String
        public let complexity: Int
    }
}

public struct BaselineLoader {
    public static func load(from path: String) throws -> BaselineReport {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(BaselineReport.self, from: data)
    }

    /// Returns functions that are NEW violations — above threshold in the report
    /// but were NOT above threshold in the baseline.
    public static func filterNewViolations(
        report: ProjectReport,
        baseline: BaselineReport,
        threshold: Int
    ) -> [FunctionComplexity] {
        // Build a lookup: (path, name) -> complexity from baseline
        var baselineLookup: [String: Int] = [:]
        for file in baseline.files {
            for fn in file.functions {
                let key = "\(file.path):\(fn.name)"
                baselineLookup[key] = fn.complexity
            }
        }

        var newViolations: [FunctionComplexity] = []
        for file in report.files {
            for fn in file.functions where fn.complexity > threshold {
                let key = "\(file.path):\(fn.name)"
                if let baselineComplexity = baselineLookup[key],
                   baselineComplexity > threshold {
                    // Pre-existing violation — suppress
                    continue
                }
                newViolations.append(fn)
            }
        }
        return newViolations
    }
}
