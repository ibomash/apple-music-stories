---
id: TASK-13.2
title: 'Phase 2: iOS simulator setup'
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
Install and configure an iOS simulator for agent-driven build and test cycles.

## Context

The macOS environment has Xcode 26.2 installed but no iOS simulators are currently available. Simulators are required for:
- Running `xcodebuild` builds with simulator destinations
- XcodeBuildMCP tools (`build_sim`, `test_sim`, `build_run_sim`)
- UI automation and screenshot capture
- Testing without a physical device

Agents need a known simulator name to use in build commands and MCP session defaults.

## Requirements

1. **Install iOS simulator runtime**:
   ```bash
   xcodebuild -downloadPlatform iOS
   ```
   This downloads the latest iOS runtime (iOS 18.x with Xcode 26.2).

2. **Create a simulator device**:
   ```bash
   xcrun simctl create "iPhone 16" \
     "com.apple.CoreSimulator.SimDeviceType.iPhone-16" \
     "com.apple.CoreSimulator.SimRuntime.iOS-18-4"
   ```
   Use iPhone 16 as the standard device for consistency.

3. **Verify simulator works**:
   ```bash
   xcrun simctl list devices available
   xcrun simctl boot "iPhone 16"
   open -a Simulator
   ```

4. **Document the default simulator** in `ios/AGENTS.md` so agents know which device to target.

## Notes

- The iOS runtime download can be large (~6GB); ensure sufficient disk space.
- If iOS 18.4 runtime is not available, use the latest available runtime and adjust device type accordingly.
- Alternative: Use `xcodebuild -downloadAllPlatforms` to get all platform simulators.

## Acceptance Criteria

- [ ] iOS simulator runtime is installed
- [ ] "iPhone 16" simulator device exists and boots
- [ ] Simulator name is documented for agent use
<!-- SECTION:DESCRIPTION:END -->
