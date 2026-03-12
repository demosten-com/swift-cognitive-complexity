# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**swift-cognitive-complexity** (`scc`) — a Swift CLI tool that calculates cognitive complexity scores for Swift/SwiftUI source files using SwiftSyntax. Designed for GitHub Actions PR quality gates with inline annotations and PR comments.

## Build & Run Commands

```bash
swift build                    # Build the project
swift build -c release         # Release build
swift test                     # Run all tests
swift test --filter <TestName> # Run a single test class/method
swift run scc <args>           # Run the CLI tool
swift run scc analyze <path>   # Analyze files (default subcommand)
swift run scc diff --base-ref origin/main  # Diff analysis against a git ref
```

Binary name: `scc` (version defined in `Sources/SCCLib/Version.swift`)

## Technology Stack

- **Swift 6.0** with SwiftPM (swift-tools-version: 6.0)
- **SwiftSyntax 600.0.1+** — AST parsing (pure-Swift parser, no compiler dependency)
- **swift-argument-parser 1.3.0+** — CLI framework
- **Hand-rolled YAML parser** — no external YAML dependency (see `Configuration.parse(yaml:)`)
- Platforms: macOS 13+, Linux (Ubuntu)

## Project Structure

```
Sources/
  scc/                          # CLI entry point (ArgumentParser)
    SCC.swift                   # @main, subcommands: Analyze, Diff
    Diff.swift                  # Diff subcommand implementation
  SCCLib/                       # Core library
    CognitiveComplexityVisitor.swift  # SyntaxVisitor — core algorithm
    ComplexityModels.swift      # FunctionComplexity, ComplexityIncrement
    ReportModels.swift          # FileReport, ProjectReport
    DiffModels.swift            # FunctionDelta, FileDiffReport, DiffReport
    ProjectAnalyzer.swift       # Multi-file concurrent analysis
    DiffAnalyzer.swift          # Git-based before/after comparison (generic over GitOperations)
    GitHelper.swift             # GitOperations protocol + GitHelper implementation
    FileDiscovery.swift         # Glob-based file discovery with include/exclude
    Configuration.swift         # YAML config loading + CLI flag merging
    OutputFormat.swift          # text/json/github/markdown formatters (analyze + diff)
    BaselineLoader.swift        # JSON baseline loading for suppressing pre-existing violations
    Version.swift               # Single source of truth for sccVersion constant
Tests/
  SCCTests/                     # Unit tests
    CognitiveComplexityVisitorTests.swift
    ConfigurationTests.swift
    FileDiscoveryTests.swift
    OutputFormatTests.swift
    DiffAnalyzerTests.swift
    DiffOutputFormatTests.swift
    GitHelperTests.swift
    BaselineTests.swift
    ProjectAnalyzerTests.swift
  Fixtures/                     # Test fixture Swift files + config
.github/workflows/
  ci.yml                        # CI: test on Ubuntu + macOS, release binaries on tag
  reusable-complexity-check.yml # Reusable workflow for PR complexity gates
```

## Architecture

1. **CLI Entry Point** (`Sources/scc/`) — AsyncParsableCommand with subcommands: `analyze` (default) and `diff`
2. **File Discovery** (`FileDiscovery`) — recursive `.swift` file enumeration with glob include/exclude patterns, always excludes `.build/`, `DerivedData/`, `.swiftpm/`
3. **SwiftSyntax Parser Layer** (`ProjectAnalyzer`) — per-file parsing via `Parser.parse(source:)`, concurrent analysis with configurable max concurrency
4. **CognitiveComplexityVisitor** — `SyntaxVisitor` subclass implementing the core algorithm:
   - Nesting depth tracker
   - Logical operator sequence detector (`&&`/`||`)
   - SwiftUI container detector (optional mode)
   - Direct recursion detector
5. **Diff Analysis** (`DiffAnalyzer`) — generic over `GitOperations` protocol; compares before/after complexity using git refs, detects new/resolved violations
6. **Baseline Support** (`BaselineLoader`) — loads a JSON baseline report to suppress pre-existing violations
7. **Output Formatting** (`OutputFormat`) — text, JSON, GitHub annotations (`::error`/`::warning`), markdown table formats for both analyze and diff reports

## Core Algorithm Rules

Based on the SonarSource Cognitive Complexity white paper (v1.7):

### Structural increments (+1 + nesting penalty)
| Construct | SwiftSyntax Node |
|-----------|-----------------|
| `if` | `IfExprSyntax` |
| `switch` | `SwitchExprSyntax` (whole switch, NOT per case) |
| `for` | `ForStmtSyntax` |
| `while` | `WhileStmtSyntax` |
| `repeat-while` | `RepeatStmtSyntax` |
| `guard` | `GuardStmtSyntax` |
| `catch` | `CatchClauseSyntax` (each `catch` is +1; `do` and `try` do NOT increment) |
| ternary `? :` | `UnresolvedTernaryExprSyntax` |
| `#if` | conditional compilation — counts like `if` |

### Hybrid increments (+1 only, no nesting penalty, but increase nesting for children)
| Construct | Detection |
|-----------|-----------|
| `else if` | `IfExprSyntax` inside `.elseBody` of another `IfExprSyntax` |
| `else` | `.elseBody` that is a `CodeBlockSyntax` (not another `IfExprSyntax`) |
| `#elseif` / `#else` | conditional compilation — counts like `else if` / `else` |

### Fundamental increments (+1 only)
- Labeled `break`/`continue` — `BreakStmtSyntax`/`ContinueStmtSyntax` where `.label` is non-nil
- Logical operator sequence switches: `&&`/`||` via `BinaryOperatorExprSyntax` in `SequenceExprSyntax` — same operator sequence gets +1 total, each switch between operators gets +1 (e.g., `a && b && c || d` = +2)
- Direct recursion: `FunctionCallExprSyntax` calling the enclosing function name

### Nesting incrementors (increase nesting, no +1)
- Closures (`ClosureExprSyntax`)
- Nested function declarations (`FunctionDeclSyntax` inside another function)
- Nested initializer declarations (`InitializerDeclSyntax` inside another function)

### No increment
`try`, `defer`, `return`, plain `break`/`continue`, `??` (nil-coalescing), `async let`, `@autoclosure`, `switch` `where` clauses (part of the case, switch already counted)

## SwiftUI-Aware Mode

When enabled (`--swiftui-aware` or `swiftui_aware: true` in config):
- Trailing closures of recognized containers do NOT increment nesting level
- `ForEach` still counts as a loop (+1 structural + nesting)
- `if`/`else`/`switch` inside `@ViewBuilder` closures count normally
- Container list is configurable via `swiftui_containers` in config
- View modifiers (`.sheet {}`, `.overlay {}`) are configurable — if the modifier name is in the container list, its trailing closure's nesting is suppressed

**SwiftUI test fixture expected scores** (`Tests/Fixtures/swiftui_view.swift`):
- `if items.isEmpty` → +1 (if)
- `else` → +1 (else)
- `ForEach(items)` → +2 (ForEach + nesting=1 from if)
- `if item.isUrgent` → +3 (if + nesting=2 from if+ForEach)
- **Total: 7** (with SwiftUI-aware mode)

## Key Data Types

- `FunctionComplexity` — per-function result (name, filePath, line, column, complexity, details)
- `ComplexityIncrement` — single scoring increment (line, description, increment value)
- `FileReport` / `ProjectReport` — aggregated results with threshold-based filtering
- `DiffReport` / `FileDiffReport` / `FunctionDelta` — PR delta analysis with new/resolved violations
- `BaselineReport` — JSON-decodable baseline for suppressing known violations
- `Configuration` — all settings with YAML loading, CLI flag merging, and sensible defaults
- `GitOperations` protocol — abstraction for git commands (enables test mocking via `DiffAnalyzer<G: GitOperations>`)

## Test Fixtures

Test fixtures live in `Tests/Fixtures/`. Key validation targets from the white paper:
- `sumOfPrimes` -> score **7**
- `getWords` -> score **1**
- `myMethod` (try/if/for/while/catch) -> score **9**
- `overriddenSymbolFrom` (Appendix C) -> score **19**

Additional fixtures: `basic.swift`, `swiftui_view.swift`, `test-config.yml`

Tests also validate that these do NOT contribute to the score: `try`, `defer`, method declarations, `??` (nil-coalescing).

## Configuration

The tool reads `.cognitive-complexity.yml` at project root. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `thresholds.warning` | 15 | Per-function warning threshold |
| `thresholds.error` | 25 | Per-function error threshold (triggers exit 1) |
| `swiftui_aware` | false | Suppress nesting for layout containers |
| `swiftui_containers` | VStack, HStack, ZStack, ... (19 total) | Container names for SwiftUI mode |
| `exclude_paths` | `**/Generated/**`, `**/Mocks/**`, `**/*.generated.swift`, `.build/**` | Glob patterns to exclude |
| `include_paths` | [] (all) | Glob patterns to include |
| `max_file_size` | 512000 | Skip files larger than this (bytes) |
| `scan_spm_packages` | true | Scan SPM package sources |
| `spm_package_paths` | [] | Explicit SPM package paths |

All settings can be overridden via CLI flags (e.g., `--warning-threshold`, `--error-threshold`, `--swiftui-aware`, `--exclude`, `--include`, `--max-file-size`).

## CLI Options

### `scc --version`
Prints the version string (from `sccVersion` in `SCCLib/Version.swift`). Both `analyze` and `diff` subcommands also print a `scc <version>` header line to stdout at the start of their `run()`.

### `scc analyze`
`--config`, `--exclude`, `--include`, `--jobs`, `--warning-threshold`, `--error-threshold`, `--swiftui-aware`, `--max-file-size`, `--baseline`, `--format`, `--verbose`, `--violations-only`

### `scc diff`
`--base-ref` (default: `origin/main`), `--changed-files`, `--config`, `--exclude`, `--include`, `--warning-threshold`, `--error-threshold`, `--swiftui-aware`, `--max-file-size`, `--format`, `--verbose`, `--violations-only`, `--fail-on-increase`

## Exit Codes

- 0: no functions above error threshold (or no new violations when using baseline)
- 1: functions above error threshold (or new violations with `--fail-on-increase`)
- 2: tool error (invalid args, parse failure, invalid format)

## GitHub Actions Integration

- **CI workflow** (`ci.yml`): Tests on Ubuntu + macOS-15, builds release binaries on version tags (linux-x86_64 with `--static-swift-stdlib`, macos-arm64), publishes GitHub Releases with checksums
- **Reusable workflow** (`reusable-complexity-check.yml`): Callable by other repos for PR complexity gates. Inputs: `warning_threshold`, `error_threshold`, `swiftui_aware`, `fail_on_increase`, `scc_version`. Caches the scc binary, uses `tj-actions/changed-files` for detection, posts sticky PR comments via `marocchino/sticky-pull-request-comment`.

## Key References

- **SonarSource Cognitive Complexity white paper** (v1.7, August 2023) — the canonical specification
- **SwiftSyntax documentation**: https://swiftpackageindex.com/swiftlang/swift-syntax
- **Swift AST Explorer**: https://swift-ast-explorer.com — useful for understanding node types
- **Reference implementations**: detekt (Kotlin, ~400 lines), gocognit (Go, ~300 lines), eslint-plugin-sonarjs (JavaScript by SonarSource)
