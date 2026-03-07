import ArgumentParser
import Foundation
import SCCLib

@main
struct SCC: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scc",
        abstract: "Swift Cognitive Complexity Analyzer v\(sccVersion)",
        version: sccVersion,
        subcommands: [Analyze.self, Diff.self],
        defaultSubcommand: Analyze.self
    )
}

struct Analyze: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze Swift files for cognitive complexity"
    )

    @Argument(help: "Path to analyze (file or directory).")
    var path: String = "."

    @Option(name: .long, help: "Path to configuration file.")
    var config: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Glob patterns to exclude.")
    var exclude: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "Glob patterns to include.")
    var include: [String] = []

    @Option(name: .long, help: "Number of parallel analysis jobs.")
    var jobs: Int?

    @Option(name: .long, help: "Warning threshold per function.")
    var warningThreshold: Int?

    @Option(name: .long, help: "Error threshold per function.")
    var errorThreshold: Int?

    @Flag(name: .long, help: "Enable SwiftUI-aware mode (suppress layout container nesting).")
    var swiftuiAware: Bool = false

    @Option(name: .long, help: "Maximum file size in bytes to analyze (default: 512000).")
    var maxFileSize: Int?

    @Option(name: .long, help: "Path to a baseline JSON report. Only new violations are reported.")
    var baseline: String?

    @Option(name: .long, help: "Output format: text, json, github, markdown.")
    var format: String = "text"

    @Flag(name: .long, help: "Show per-line increment details.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Show only functions exceeding warning or error thresholds.")
    var violationsOnly: Bool = false

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

            let analyzer = ProjectAnalyzer(configuration: cfg, maxConcurrency: jobs)
            let report = try await analyzer.analyze(paths: [path])

            let output = outputFormat.format(report, verbose: verbose, violationsOnly: violationsOnly)
            print(output)

            if let baselinePath = baseline {
                let baselineReport = try BaselineLoader.load(from: baselinePath)
                let newViolations = BaselineLoader.filterNewViolations(
                    report: report,
                    baseline: baselineReport,
                    threshold: cfg.errorThreshold
                )
                if !newViolations.isEmpty {
                    throw ExitCode(1)
                }
            } else if !report.functionsAboveError.isEmpty {
                throw ExitCode(1)
            }
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            throw ExitCode(2)
        }
    }
}
