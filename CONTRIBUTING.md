# Contributing

Thank you for your interest in contributing to swift-cognitive-complexity! This is a focused CLI tool that calculates cognitive complexity scores for Swift and SwiftUI source files. The project is maintained by a single developer, so response times on PRs and issues may vary — your patience is appreciated. Both human-written and AI-assisted contributions are welcome.

## Getting Started

**Prerequisites:** Swift 6.0+ toolchain on macOS 13+ or Linux (Ubuntu).

```bash
swift build              # Build the project
swift test               # Run all tests
swift run scc analyze .  # Analyze the current directory
```

For a deep dive into the codebase architecture, algorithm rules, data types, and project structure, see [CLAUDE.md](CLAUDE.md).

## AI-Assisted Contributions

Contributions created with the help of AI tools — including Claude Code, GitHub Copilot, ChatGPT, Cursor, or any other AI assistant — are welcome and treated identically to fully human-written contributions.

We ask that you:

- **Disclose AI assistance** in your PR description. This is for transparency, not gatekeeping.
- **Understand the code you submit.** Regardless of how it was produced, you are responsible for its correctness and should be able to discuss it during review.
- **Ensure it passes all tests** just like any other contribution.

This project itself uses [CLAUDE.md](CLAUDE.md) as a guide for AI-assisted development, so AI tooling is a natural part of the workflow.

## What to Contribute

**Good contribution areas:**

- Bug fixes, especially edge cases in complexity scoring
- Support for new Swift syntax constructs as the language evolves
- Test cases and fixture files that validate expected scores
- Documentation improvements
- CI and workflow improvements

**Likely to need prior discussion (open an issue first):**

- Large new features
- Adding external dependencies — the project deliberately minimizes them
- Changes to the core algorithm that deviate from the cognitive complexity specification

## Pull Request Process

1. Fork the repo and create a feature branch from `main`.
2. Keep PRs focused — one logical change per PR.
3. Use sentence-case, descriptive commit messages (e.g., "Added ...", "Fixed ...").
4. Ensure `swift build` succeeds and `swift test` passes. CI runs on both macOS and Linux.
5. The CI also runs a self-complexity check on the codebase, so contributed code should maintain reasonable cognitive complexity.
6. For algorithm changes, reference the relevant section of the cognitive complexity specification. The tool is based on the cognitive complexity white paper by G. Ann Campbell, originally published by SonarSource (attribution only — this project is not affiliated with SonarSource).
7. Add or update tests for any behavioral changes. Test fixtures go in `Tests/Fixtures/`.

## Reporting Issues

Use GitHub Issues. For incorrect complexity scoring, please include:

- The Swift code snippet
- The score `scc` reports
- The expected score, with reasoning

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE) that covers this project.
