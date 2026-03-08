# CarpdmTerminal

CarpdmTerminal is a macOS-native AI coding workspace that combines project-aware task orchestration, Obsidian-backed memory, and terminal-first agent execution.

## Stack

- SwiftUI + AppKit
- XcodeGen (`project.yml`)
- Swift Package Manager for dependency resolution and test execution
- GRDB for app-local SQLite state
- Yams for markdown frontmatter parsing
- SwiftTerm for PTY-backed terminal and agent process execution

## Prerequisites

- macOS 14+
- XcodeGen to generate the Xcode project from `project.yml`
- Full Xcode installation for app bundle builds

## Local development

```bash
swift test
```

Run the app directly from Terminal:

```bash
swift run CarpdmTerminalApp
```

Generate the Xcode project once `xcodegen` is available:

```bash
xcodegen generate
```

Open the generated project with Xcode:

```bash
open CarpdmTerminal.xcodeproj
```

## GitHub CI / release

- CI runs via `.github/workflows/ci.yml`
- Release packaging, notarization, GitHub Release upload, and Sparkle appcast generation are defined in `.github/workflows/release.yml`
- Signed releases now require the GitHub environment `production-release`
- Distribution configuration templates live in `Config/`
- Release helper scripts live in `scripts/release/`
- Operational notes for private-repo distribution live in `docs/distribution/github-private-distribution.md`
- Public-repo hardening guidance lives in `docs/distribution/github-public-distribution.md`
- Security reporting guidance lives in `SECURITY.md`

The generated application stores app metadata at:

`~/Library/Application Support/CarpdmTerminal/app.sqlite`

Project memory is stored inside each project at:

`<project>/.carpdm/vault`
