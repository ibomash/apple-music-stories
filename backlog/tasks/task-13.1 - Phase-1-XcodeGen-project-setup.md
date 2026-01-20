---
id: TASK-13.1
title: 'Phase 1: XcodeGen project setup'
status: Later
assignee: []
created_date: '2026-01-20 15:23'
labels:
  - macOS
dependencies: []
parent_task_id: TASK-13
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up XcodeGen to generate the Xcode project for MusicStoryRenderer from a `project.yml` spec.

## Context

The iOS app code exists under `ios/MusicStoryRenderer/` but there is no Xcode project yet. The architecture uses a Swift Package for core library tests (`swift test`) but the full app with MusicKit integration requires an Xcode project for:
- MusicKit capability and entitlements
- Code signing and provisioning
- Simulator/device builds

Using XcodeGen allows the project to be regenerated from a spec file, avoiding manual `.xcodeproj` edits and merge conflicts. This is essential for agent-driven development where the agent may add/remove source files.

## Requirements

1. **Install XcodeGen**: `brew install xcodegen`

2. **Create `ios/MusicStoryRenderer/project.yml`** with:
   - Project name: `MusicStoryRenderer`
   - App target with all sources:
     - `App/*.swift`
     - `Models/*.swift`
     - `Playback/*.swift`
     - `Rendering/*.swift`
     - `StoryParser.swift`
     - `StoryPackageLoader.swift`
     - `StoryDocumentStore.swift`
   - Test target with `Tests/MusicStoryRendererCoreTests/*.swift`
   - iOS 17+ deployment target
   - Swift 6.2 language version
   - MusicKit capability
   - Entitlements file reference

3. **Create `ios/MusicStoryRenderer/MusicStoryRenderer.entitlements`** with:
   - `com.apple.developer.musickit` entitlement

4. **Create `ios/MusicStoryRenderer/Info.plist`** with:
   - `NSAppleMusicUsageDescription` usage string
   - Bundle identifier placeholder
   - Required app metadata

5. **Update `.gitignore`** to exclude:
   - `ios/MusicStoryRenderer/*.xcodeproj`
   - `ios/MusicStoryRenderer/*.xcworkspace`

6. **Verify generation**: Run `xcodegen generate` and confirm the project opens in Xcode without errors.

## Acceptance Criteria

- [ ] `project.yml` exists and is valid
- [ ] `xcodegen generate` produces a working `.xcodeproj`
- [ ] MusicKit entitlement is configured
- [ ] Info.plist has usage description
- [ ] Generated project is gitignored
<!-- SECTION:DESCRIPTION:END -->
