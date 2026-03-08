import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

public struct FileDiscovery: Sendable {
    public let includePaths: [String]
    public let excludePaths: [String]

    private static let alwaysExcluded = [".build/", "DerivedData/", ".swiftpm/"]

    public init(includePaths: [String] = [], excludePaths: [String] = []) {
        self.includePaths = includePaths
        self.excludePaths = excludePaths
    }

    public func discoverFiles(in roots: [String]) throws -> [String] {
        let fm = FileManager.default
        var result: [String] = []

        for root in roots {
            let absoluteRoot = root.hasPrefix("/") ? root : fm.currentDirectoryPath + "/" + root
            let normalized = (absoluteRoot as NSString).standardizingPath

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: normalized, isDirectory: &isDir) else {
                throw FileDiscoveryError.pathNotFound(root)
            }

            if !isDir.boolValue {
                if normalized.hasSuffix(".swift") && shouldInclude(path: normalized) {
                    result.append(normalized)
                }
                continue
            }

            try discoverFilesInDirectory(normalized, root: root, into: &result)
        }

        return result.sorted()
    }

    private func discoverFilesInDirectory(_ normalized: String, root: String, into result: inout [String]) throws {
        guard let enumerator = FileManager.default.enumerator(atPath: normalized) else {
            throw FileDiscoveryError.cannotEnumerate(root)
        }

        while let relativePath = enumerator.nextObject() as? String {
            if Self.alwaysExcluded.contains(where: { relativePath.contains($0) }) {
                continue
            }
            guard relativePath.hasSuffix(".swift") else { continue }
            guard shouldInclude(path: relativePath) else { continue }

            result.append(normalized + "/" + relativePath)
        }
    }

    public func shouldInclude(path: String) -> Bool {
        // Check excludes
        for pattern in excludePaths {
            if Self.matchesGlob(path: path, pattern: pattern) {
                return false
            }
        }

        // Check includes (empty means include all)
        if !includePaths.isEmpty {
            let matched = includePaths.contains { Self.matchesGlob(path: path, pattern: $0) }
            if !matched { return false }
        }

        return true
    }

    public static func matchesGlob(path: String, pattern: String) -> Bool {
        if pattern.contains("**") {
            return matchesDoubleStarPattern(path: path, pattern: pattern)
        }
        return fnmatch(pattern, path, FNM_PATHNAME) == 0
    }

    /// Handles `**` glob patterns by matching zero or more directory segments.
    /// Splits the pattern at each `**`, then verifies each segment matches
    /// in order within the path, with `**` consuming zero or more path components.
    private static func matchesDoubleStarPattern(path: String, pattern: String) -> Bool {
        let segments = pattern.components(separatedBy: "**")

        // Build a regex-like match: each segment must appear in order,
        // with ** allowing any number of path components between them.
        // We use fnmatch per-segment against substrings of the path.

        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        // Clean segments: remove leading/trailing slashes from each segment
        let cleanedSegments = segments.map { seg -> String in
            var s = seg
            if s.hasPrefix("/") { s = String(s.dropFirst()) }
            if s.hasSuffix("/") { s = String(s.dropLast()) }
            return s
        }

        return matchSegments(cleanedSegments, against: pathComponents, segIndex: 0, pathIndex: 0)
    }

    private static func matchSegments(_ segments: [String], against pathComponents: [String], segIndex: Int, pathIndex: Int) -> Bool {
        if segIndex >= segments.count {
            return true
        }

        let segment = segments[segIndex]

        // Empty segment means ** was at start/end or adjacent to another **
        if segment.isEmpty {
            return matchSegments(segments, against: pathComponents, segIndex: segIndex + 1, pathIndex: pathIndex)
        }

        let segParts = segment.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let isLast = segIndex == segments.count - 1
        let maxStart = pathComponents.count - segParts.count

        for start in pathIndex...max(pathIndex, maxStart) {
            if start + segParts.count > pathComponents.count { break }

            if allSegmentPartsMatch(segParts, at: start, in: pathComponents) {
                let nextPathIndex = start + segParts.count
                if handleSegmentMatch(segments, against: pathComponents, segIndex: segIndex, nextPathIndex: nextPathIndex, isLast: isLast) {
                    return true
                }
            }
        }

        return false
    }

    private static func allSegmentPartsMatch(_ segParts: [String], at startIndex: Int, in pathComponents: [String]) -> Bool {
        for (i, segPart) in segParts.enumerated() {
            if fnmatch(segPart, pathComponents[startIndex + i], 0) != 0 {
                return false
            }
        }
        return true
    }

    private static func handleSegmentMatch(_ segments: [String], against pathComponents: [String], segIndex: Int, nextPathIndex: Int, isLast: Bool) -> Bool {
        if isLast {
            if segIndex == segments.count - 1 && segments.last == "" {
                return true
            }
            if nextPathIndex == pathComponents.count {
                return true
            }
            if segIndex + 1 < segments.count {
                return matchSegments(segments, against: pathComponents, segIndex: segIndex + 1, pathIndex: nextPathIndex)
            }
        } else {
            if matchSegments(segments, against: pathComponents, segIndex: segIndex + 1, pathIndex: nextPathIndex) {
                return true
            }
        }
        return false
    }
}

public enum FileDiscoveryError: Error, CustomStringConvertible {
    case pathNotFound(String)
    case cannotEnumerate(String)

    public var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .cannotEnumerate(let path):
            return "Cannot enumerate directory: \(path)"
        }
    }
}
