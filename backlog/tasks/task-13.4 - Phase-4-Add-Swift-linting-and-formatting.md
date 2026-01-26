---
id: TASK-13.4
title: 'Phase 4: Add Swift linting and formatting'
status: Done
assignee: []
created_date: '2026-01-20 15:23'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
parent_task_id: TASK-13
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add optional SwiftLint and SwiftFormat configuration for code quality automation.

## Context

Linting and formatting tools help agents produce consistent, high-quality code. When an agent writes Swift code, it can run these tools to catch style violations and auto-fix formatting issues before committing.

This phase is **optional** and lower priority than the core build/test workflow. It can be done on any platform where the tools are installed.

## Requirements

1. **Install tools** (if not present):
   ```bash
   brew install swiftlint swiftformat
   ```

2. **Create `ios/MusicStoryRenderer/.swiftlint.yml`** with sensible defaults:
   ```yaml
   # SwiftLint configuration for MusicStoryRenderer
   
   disabled_rules:
     - line_length  # Allow longer lines for readability
     - trailing_whitespace
   
   opt_in_rules:
     - empty_count
     - closure_spacing
     - explicit_init
   
   excluded:
     - Tests
   
   line_length:
     warning: 120
     error: 200
   
   type_body_length:
     warning: 300
     error: 500
   
   file_length:
     warning: 500
     error: 1000
   ```

3. **Create `ios/MusicStoryRenderer/.swiftformat`** with:
   ```
   # SwiftFormat configuration
   --swiftversion 6.2
   --indent 4
   --indentcase false
   --trimwhitespace always
   --voidtype void
   --wraparguments before-first
   --wrapcollections before-first
   --maxwidth 120
   ```

4. **Add lint/format commands** to documentation:
   ```bash
   # Lint
   swiftlint lint --config ios/MusicStoryRenderer/.swiftlint.yml ios/MusicStoryRenderer
   
   # Format (check only)
   swiftformat --lint ios/MusicStoryRenderer
   
   # Format (apply changes)
   swiftformat ios/MusicStoryRenderer
   ```

5. **Optionally add to helper script** (`scripts/ios.sh`):
   ```bash
   lint) swiftlint lint --config ios/MusicStoryRenderer/.swiftlint.yml ios/MusicStoryRenderer ;;
   format) swiftformat ios/MusicStoryRenderer ;;
   ```

## Notes

- SwiftLint and SwiftFormat can be installed on Linux via other methods but Homebrew is easiest on macOS.
- Start with lenient rules; tighten as the codebase matures.
- Agents should run lint after making changes but formatting can be applied automatically.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `.swiftlint.yml` exists with reasonable defaults
- [ ] #2 `.swiftformat` exists with Swift 6.2 settings
- [ ] #3 `swiftlint lint` runs without crashes (warnings OK)
- [ ] #4 `swiftformat --lint` runs without crashes
- [ ] #5 Commands documented in `ios/AGENTS.md`
<!-- SECTION:DESCRIPTION:END -->

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented SwiftLint/SwiftFormat setup:
- Added ios/MusicStoryRenderer/.swiftlint.yml and .swiftformat configs.
- Documented lint/format commands in ios/AGENTS.md and updated scripts/ios.sh with lint/format helpers.
- Installed swiftlint/swiftformat via Homebrew.

Checks:
- swiftlint lint --config ios/MusicStoryRenderer/.swiftlint.yml ios/MusicStoryRenderer (reported violations in StoryParser.swift and build artifacts; no crash).
- swiftformat --lint ios/MusicStoryRenderer (reported formatting violations across multiple files).
<!-- SECTION:NOTES:END -->
