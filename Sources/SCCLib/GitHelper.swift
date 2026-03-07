import Foundation

public enum GitHelperError: Error, CustomStringConvertible {
    case notAGitRepository
    case commandFailed(command: String, stderr: String)

    public var description: String {
        switch self {
        case .notAGitRepository:
            return "Not a git repository"
        case .commandFailed(let command, let stderr):
            return "Git command failed: \(command)\n\(stderr)"
        }
    }
}

public protocol GitOperations: Sendable {
    func changedSwiftFiles(baseRef: String) throws -> [String]
    func fileContent(at path: String, ref: String) throws -> String?
    func repositoryRoot() throws -> String
}

public struct GitHelper: GitOperations, Sendable {
    public let workingDirectory: String

    public init(workingDirectory: String = ".") {
        self.workingDirectory = workingDirectory
    }

    public func changedSwiftFiles(baseRef: String) throws -> [String] {
        let output = try runGit(["diff", "--name-only", "--diff-filter=ACMRT", "\(baseRef)...HEAD", "--", "*.swift"])
        return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    public func fileContent(at path: String, ref: String) throws -> String? {
        do {
            return try runGit(["show", "\(ref):\(path)"])
        } catch GitHelperError.commandFailed {
            return nil
        }
    }

    public func repositoryRoot() throws -> String {
        let output = try runGit(["rev-parse", "--show-toplevel"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runGit(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outString = String(data: outData, encoding: .utf8) ?? ""
        let errString = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            if errString.contains("not a git repository") {
                throw GitHelperError.notAGitRepository
            }
            throw GitHelperError.commandFailed(
                command: "git \(arguments.joined(separator: " "))",
                stderr: errString
            )
        }

        return outString
    }
}
