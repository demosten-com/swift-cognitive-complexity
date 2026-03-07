import ArgumentParser
import Foundation
import SCCLib

struct Diff: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze complexity changes between git refs"
    )

    @Option(name: .long, help: "Git ref to compare against.")
    var baseRef: String = "origin/main"

    @Option(name: .long, help: "File containing newline-separated list of changed files.")
    var changedFiles: String?

    @Argument(help: "Path to repository root.")
    var path: String = "."

    @Option(name: .long, help: "Path to configuration file.")
    var config: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Glob patterns to exclude.")
    var exclude: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "Glob patterns to include.")
    var include: [String] = []

    @Option(name: .long, help: "Warning threshold per function.")
    var warningThreshold: Int?

    @Option(name: .long, help: "Error threshold per function.")
    var errorThreshold: Int?

    @Flag(name: .long, help: "Enable SwiftUI-aware mode (suppress layout container nesting).")
    var swiftuiAware: Bool = false

    @Option(name: .long, help: "Maximum file size in bytes to analyze (default: 512000).")
    var maxFileSize: Int?

    @Option(name: .long, help: "Output format: text, json, github, markdown.")
    var format: String = "text"

    @Flag(name: .long, help: "Show per-line increment details.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Show only functions exceeding warning or error thresholds.")
    var violationsOnly: Bool = false

    @Flag(name: .long, help: "Exit 1 if any function's complexity increased above warning threshold.")
    var failOnIncrease: Bool = false

    func run() async throws {
        print("scc \(sccVersion)")

        guard let outputFormat = OutputFormat(rawValue: format) else {
            FileHandle.standardError.write(Data("Error: Invalid format '\(format)'. Valid formats: \(OutputFormat.allCases.map(\.rawValue).joined(separator: ", "))\n".utf8))
            throw ExitCode(2)
        }

        do {
            let configPath = config ?? ".cognitive-complexity.yml"
            var cfg: Configuration
            if config != nil {
                cfg = try Configuration.load(from: configPath)
            } else {
                cfg = Configuration.loadIfExists(from: configPath)
            }

            cfg = cfg.merging(
                cliWarningThreshold: warningThreshold,
                cliErrorThreshold: errorThreshold,
                cliExclude: exclude,
                cliInclude: include,
                cliSwiftuiAware: swiftuiAware ? true : nil,
                cliMaxFileSize: maxFileSize
            )

            var fileList: [String]? = nil
            if let changedFilesPath = changedFiles {
                let content = try String(contentsOfFile: changedFilesPath, encoding: .utf8)
                fileList = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            }

            let gitHelper = GitHelper(workingDirectory: path)
            let diffAnalyzer = DiffAnalyzer(configuration: cfg, gitOperations: gitHelper)
            let report = try await diffAnalyzer.analyze(baseRef: baseRef, changedFiles: fileList)

            let output = outputFormat.format(report, verbose: verbose, violationsOnly: violationsOnly)
            print(output)

            if failOnIncrease && !report.newViolations.isEmpty {
                throw ExitCode(1)
            }

            let hasErrors = report.changedFiles.flatMap(\.functionDeltas).contains { fd in
                if let after = fd.afterComplexity {
                    return after > cfg.errorThreshold
                }
                return false
            }
            if hasErrors {
                throw ExitCode(1)
            }
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            throw ExitCode(2)
        }
    }
}
