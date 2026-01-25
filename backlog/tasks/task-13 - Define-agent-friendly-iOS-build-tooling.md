---
id: TASK-13
title: Define agent-friendly iOS build tooling
status: Done
assignee: []
created_date: '2026-01-17 05:56'
updated_date: '2026-01-24 21:43'
labels: []
dependencies: []
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define a CLI-driven build/test workflow for the iOS app that minimizes reliance on Xcode UI, including formatting, linting, and test automation.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Current State

The iOS code exists under `ios/MusicStoryRenderer/` as a Swift Package with:
- `Package.swift` defining `MusicStoryRendererCore` library (for parser + loader)
- App sources under `App/`, `Playback/`, `Rendering/` (excluded from SwiftPM library)
- Core tests that run via `swift test`

**No Xcode project exists yet.** The architecture doc notes: "Create or open a local Xcode project in `ios/MusicStoryRenderer` (the repo does not include an `.xcodeproj` yet)."

## Tooling Assessment

| Tool | Status | Notes |
|------|--------|-------|
| Xcode | 26.2 installed | Full CLI tools available |
| swiftlint | Not installed | Optional, can be added |
| swiftformat | Not installed | Optional, can be added |
| Simulators | None installed | Need to install via Xcode |
| XcodeBuildMCP | Available | MCP server configured |
| Apple Docs MCP | Available | MCP server configured |

## Recommended Approach: XcodeGen + XcodeBuildMCP

Use **XcodeGen** to generate the Xcode project from a `project.yml` spec. This approach:
1. Keeps the Xcode project reproducible and diff-friendly (no manual xcodeproj commits)
2. Lets agents regenerate the project after structure changes
3. Works seamlessly with XcodeBuildMCP for build/test/run cycles

### Phase 1: Project Generation Setup

1. **Install XcodeGen**: `brew install xcodegen`
2. **Create `ios/MusicStoryRenderer/project.yml`** with:
   - App target (`MusicStoryRenderer`) with all App/Playback/Rendering sources
   - MusicKit capability + entitlements
   - iOS 17+ deployment target, Swift 6.2
   - Test target linking to the app
3. **Generate project**: `xcodegen generate` from `ios/MusicStoryRenderer`
4. **Add `.xcodeproj` to `.gitignore`** (generated, not committed)

### Phase 2: Simulator Setup

1. **Install an iOS simulator runtime** (agents can prompt for this):
   ```bash
   xcodebuild -downloadPlatform iOS
   xcrun simctl create "iPhone 16" "com.apple.CoreSimulator.SimDeviceType.iPhone-16" "com.apple.CoreSimulator.SimRuntime.iOS-18-4"
   ```
2. **Document default simulator** in AGENTS.md

### Phase 3: Build/Test Commands

Record canonical commands in `ios/AGENTS.md`:

```bash
# Generate project (after structure changes)
cd ios/MusicStoryRenderer && xcodegen generate

# Build for simulator
xcodebuild -project MusicStoryRenderer.xcodeproj \
  -scheme MusicStoryRenderer \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build

# Run tests
xcodebuild test -project MusicStoryRenderer.xcodeproj \
  -scheme MusicStoryRenderer \
  -destination "platform=iOS Simulator,name=iPhone 16"

# Core library tests (no Xcode needed)
swift test
```

### Phase 4: Linting/Formatting (Optional)

If desired, add minimal configs:
- `ios/MusicStoryRenderer/.swiftlint.yml` with sensible defaults
- `ios/MusicStoryRenderer/.swiftformat` config

Commands:
```bash
brew install swiftlint swiftformat
swiftlint --config ios/MusicStoryRenderer/.swiftlint.yml
swiftformat ios/MusicStoryRenderer --config ios/MusicStoryRenderer/.swiftformat
```

### Phase 5: XcodeBuildMCP Integration

With the generated project, agents can use XcodeBuildMCP tools:
1. `session-set-defaults` to set project path and scheme
2. `build_sim` / `build_run_sim` for build loops
3. `test_sim` for automated testing
4. `screenshot` / `describe_ui` for UI validation

### Phase 6: Documentation

Update `ios/AGENTS.md` with:
- XcodeGen regeneration command
- Build/test/lint commands
- Simulator setup instructions
- MCP tool usage patterns
- Safe command allowlist

## Deliverables

1. `ios/MusicStoryRenderer/project.yml` - XcodeGen spec
2. `ios/MusicStoryRenderer/.swiftlint.yml` - (optional) lint config
3. `ios/MusicStoryRenderer/.swiftformat` - (optional) format config
4. Updated `ios/AGENTS.md` with full CLI workflow
5. Updated `.gitignore` to exclude generated `.xcodeproj`

## Alternative Approaches Considered

| Approach | Pros | Cons |
|----------|------|------|
| Commit .xcodeproj | No generation step | Large diffs, merge conflicts, manual edits |
| Tuist | More powerful | Heavier, less familiar |
| Pure SwiftPM | Simplest | Can't add MusicKit capability, limited for apps |
| XcodeGen | Reproducible, lightweight | Extra tool dependency |

**Recommendation**: XcodeGen is the best fit for this project size and agent-first workflow.
<!-- SECTION:PLAN:END -->
