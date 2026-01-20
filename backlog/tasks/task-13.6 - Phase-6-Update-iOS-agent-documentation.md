---
id: TASK-13.6
title: 'Phase 6: Update iOS agent documentation'
status: Later
assignee: []
created_date: '2026-01-20 15:24'
labels: []
dependencies: []
parent_task_id: TASK-13
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Consolidate all iOS build/test/lint commands and workflows into comprehensive agent documentation.

## Context

After completing Phases 1-5, the `ios/AGENTS.md` file needs to be updated with all the commands, workflows, and best practices for agent-driven iOS development. This documentation is what agents read to understand how to work with the iOS codebase.

## Requirements

1. **Update `ios/AGENTS.md`** to include:

   a. **Swift toolchain setup** (existing, verify still accurate):
      ```bash
      export PATH="$HOME/.swiftenv/bin:$PATH"
      eval "$(swiftenv init -)"
      ```

   b. **Project generation**:
      ```bash
      cd ios/MusicStoryRenderer
      xcodegen generate
      ```
      Note: Run after adding/removing source files.

   c. **Build commands**:
      ```bash
      # Core library tests (any platform)
      swift test
      
      # Full app build (macOS only)
      xcodebuild -project MusicStoryRenderer.xcodeproj \
        -scheme MusicStoryRenderer \
        -destination "platform=iOS Simulator,name=iPhone 16" \
        build
      
      # Run tests
      xcodebuild test -project MusicStoryRenderer.xcodeproj \
        -scheme MusicStoryRenderer \
        -destination "platform=iOS Simulator,name=iPhone 16"
      ```

   d. **Linting/formatting** (if Phase 4 completed):
      ```bash
      swiftlint lint --config .swiftlint.yml
      swiftformat --lint .
      ```

   e. **XcodeBuildMCP tools** section:
      - Session defaults to set
      - Common tools and their purposes
      - Example workflow for build-fix loop

   f. **Safe command allowlist**:
      - `xcodebuild`, `xcodegen`, `xcrun simctl`
      - `swift build`, `swift test`
      - `swiftlint`, `swiftformat`
      - `git status`, `git diff`, `git log`

   g. **Coding conventions**:
      - No force unwraps
      - MVVM architecture (views separate from view models)
      - Prefer async/await
      - SwiftUI for all new views

2. **Update `ios/architecture.md`** Build + Run section to reference the new workflow.

3. **Update `ios/development.md`** if any commands changed.

## Template

```markdown
# iOS Agent Instructions

Read `ios/architecture.md` for app architecture. Keep `ios/architecture.md` and `ios/status.md` updated.

## Swift Toolchain

\`\`\`bash
export PATH="$HOME/.swiftenv/bin:$PATH"
eval "$(swiftenv init -)"
\`\`\`

## Project Generation

After adding/removing source files:
\`\`\`bash
cd ios/MusicStoryRenderer && xcodegen generate
\`\`\`

## Build Commands

| Command | Platform | Purpose |
|---------|----------|---------|
| `swift test` | Any | Core library tests |
| `xcodebuild build ...` | macOS | Full app build |
| `xcodebuild test ...` | macOS | Run all tests |

## XcodeBuildMCP

Set session defaults before using MCP tools:
- Project: `ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj`
- Scheme: `MusicStoryRenderer`
- Simulator: `iPhone 16`

## Coding Conventions

- No force unwraps (`!`)
- MVVM architecture
- SwiftUI for views
- async/await for async code
```

## Acceptance Criteria

- [ ] `ios/AGENTS.md` has all build/test/lint commands
- [ ] XcodeBuildMCP usage is documented
- [ ] Coding conventions are specified
- [ ] Safe command allowlist is defined
- [ ] Cross-references to architecture.md are correct
<!-- SECTION:DESCRIPTION:END -->
