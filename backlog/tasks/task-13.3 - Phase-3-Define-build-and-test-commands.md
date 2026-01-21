---
id: TASK-13.3
title: 'Phase 3: Define build and test commands'
status: Done
assignee: []
created_date: '2026-01-20 15:23'
updated_date: '2026-01-20 22:41'
labels:
  - macOS
dependencies: []
parent_task_id: TASK-13
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define and validate the canonical CLI commands for building and testing the iOS app.

## Context

With the XcodeGen project (TASK-13.1) and simulator (TASK-13.2) in place, we need to establish the standard commands that agents and developers use for build/test cycles. These commands will be documented in `ios/AGENTS.md` and used by XcodeBuildMCP tools.

## Requirements

1. **Validate project generation command**:
   ```bash
   cd ios/MusicStoryRenderer
   xcodegen generate
   ```
   This should be run after any source file additions/removals.

2. **Validate build command**:
   ```bash
   xcodebuild -project MusicStoryRenderer.xcodeproj \
     -scheme MusicStoryRenderer \
     -destination "platform=iOS Simulator,name=iPhone 16" \
     build
   ```
   Confirm this builds successfully with no errors.

3. **Validate test command**:
   ```bash
   xcodebuild test -project MusicStoryRenderer.xcodeproj \
     -scheme MusicStoryRenderer \
     -destination "platform=iOS Simulator,name=iPhone 16"
   ```
   Confirm tests run and pass.

4. **Validate core library tests** (works on any platform):
   ```bash
   cd ios/MusicStoryRenderer
   swift test
   ```

5. **Document clean build command**:
   ```bash
   xcodebuild clean -project MusicStoryRenderer.xcodeproj \
     -scheme MusicStoryRenderer
   ```

6. **Create a helper script** (optional) at `scripts/ios.sh`:
   ```bash
   #!/bin/bash
   set -e
   cd ios/MusicStoryRenderer
   
   case "$1" in
     generate) xcodegen generate ;;
     build) xcodebuild -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" build ;;
     test) xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" ;;
     swift-test) swift test ;;
     clean) xcodebuild clean -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer ;;
     *) echo "Usage: $0 {generate|build|test|swift-test|clean}" ;;
   esac
   ```

## Notes

- The scheme name should match what XcodeGen generates (typically the target name).
- If the project uses a workspace, adjust commands to use `-workspace` instead of `-project`.
- Build warnings are acceptable; focus on zero errors.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `xcodegen generate` works
- [ ] #2 `xcodebuild build` succeeds
- [ ] #3 `xcodebuild test` runs and passes
- [ ] #4 `swift test` continues to work for core library
- [ ] #5 Commands are documented in `ios/AGENTS.md`
<!-- SECTION:DESCRIPTION:END -->

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validated xcodegen generate, xcodebuild build/test, and swift test. Added MusicStoryRendererCore framework target plus scheme test action so xcodebuild test includes core tests. Added scripts/ios.sh helper and documented commands in ios/AGENTS.md. xcodebuild test emits non-exhaustive switch warning in Playback/AppleMusicPlaybackController.swift; swift test ran with system Swift since swiftenv was unavailable.
<!-- SECTION:NOTES:END -->
