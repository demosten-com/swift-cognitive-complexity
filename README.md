# Swift Cognitive Complexity Analyzer (scc)

A command-line tool that calculates [cognitive complexity](https://www.sonarsource.com/docs/CognitiveComplexity.pdf) scores for Swift and SwiftUI source files. Use it locally or as a GitHub Actions PR quality gate.

## What is Cognitive Complexity?

You've probably heard of cyclomatic complexity — it counts the number of independent paths through your code. It's useful for testing but it has a big problem: it doesn't reflect how hard the code is to *understand*. A `switch` with 10 cases gets a similar cyclomatic score as a deeply nested loop with conditionals — yet the nested loop is clearly harder to read.

Cognitive complexity fixes this. It was created by G. Ann Campbell at SonarSource and it measures how difficult a piece of code is for a human to understand. The key idea is simple — nesting is penalized. An `if` inside a `for` inside another `if` costs more than three flat `if` statements. At the same time, things like `switch` (as a whole) or nil-coalescing (`??`) are treated as easy to read and are scored lightly or not at all.

Why should you care? Because we spend most of our time reading code, not writing it. High cognitive complexity means more bugs, slower code reviews, and harder onboarding. Keeping it low makes your codebase healthier. And in the age of AI coding agents — they also struggle more with deeply nested, complex control flow. Lower cognitive complexity likely means better results from your AI tools too.

## Quick Start

```bash
# Build from source (requires Swift 6.0+, macOS or Linux)
swift build -c release

# Analyze a file or project
.build/release/scc analyze path/to/file.swift
.build/release/scc analyze .

# Compare against a base branch
.build/release/scc diff --base-ref origin/main

# Check version
.build/release/scc --version
```

## GitHub Actions

Add to `.github/workflows/complexity.yml`:

```yaml
name: PR Complexity Check
on:
  pull_request:
    paths: ['**/*.swift']

jobs:
  complexity:
    uses: <owner>/swift-cognitive-complexity/.github/workflows/reusable-complexity-check.yml@v1
    with:
      warning_threshold: 15
      error_threshold: 25
      swiftui_aware: true
    permissions:
      contents: read
      pull-requests: write
```

Replace `<owner>` with the GitHub org or user hosting this repository.

## Configuration

Create `.cognitive-complexity.yml` at your project root:

```yaml
thresholds:
  warning: 15
  error: 25

swiftui_aware: true

exclude_paths:
  - "**/Generated/**"
  - "**/Mocks/**"
  - "**/*.generated.swift"
```

All settings can be overridden via CLI flags. Run `scc analyze --help` or `scc diff --help` for the full list.

## SwiftUI-Aware Mode

With `--swiftui-aware`, layout containers like `VStack`, `HStack`, and `NavigationStack` don't increment nesting depth. This avoids penalizing SwiftUI's natural declarative structure while still catching real branching complexity.

## Output Formats

| Format | Flag | Use case |
|--------|------|----------|
| `text` | `--format text` | Terminal output (default) |
| `json` | `--format json` | Machine-readable, downstream tooling |
| `github` | `--format github` | Inline PR annotations |
| `markdown` | `--format markdown` | PR comments via sticky-comment actions |

## Filtering Output

Use `--violations-only` to show only functions that exceed the warning or error thresholds. This works with both `analyze` and `diff` subcommands and all output formats.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No functions above error threshold |
| 1 | Functions above error threshold (or `--fail-on-increase` triggered) |
| 2 | Tool error (invalid arguments, parse failure) |

## Attribution

This tool implements the cognitive complexity metric as described by G. Ann Campbell in the [SonarSource white paper](https://www.sonarsource.com/docs/CognitiveComplexity.pdf) (v1.7, 2023) and the [ACM conference paper](https://dl.acm.org/doi/10.1145/3194164.3194186).

This is an independent project, not affiliated with or endorsed by SonarSource.

## License

[MIT](LICENSE)
