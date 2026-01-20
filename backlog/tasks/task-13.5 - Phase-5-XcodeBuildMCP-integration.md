---
id: TASK-13.5
title: 'Phase 5: XcodeBuildMCP integration'
status: Later
assignee: []
created_date: '2026-01-20 15:24'
labels:
  - macOS
dependencies: []
parent_task_id: TASK-13
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure XcodeBuildMCP session defaults and validate agent build/test/run workflows.

## Context

XcodeBuildMCP is an MCP server that exposes Xcode build capabilities to AI agents. It allows agents to:
- Build and run apps in the simulator
- Run tests and see results
- Take screenshots and describe UI
- Interact with the simulator (tap, type, swipe)

With the XcodeGen project and simulator in place, we need to configure XcodeBuildMCP so agents can use it effectively.

## Requirements

1. **Verify XcodeBuildMCP is available**:
   The MCP server should be configured in the agent's MCP config (e.g., `opencode.jsonc`):
   ```json
   "XcodeBuildMCP": {
     "command": "npx",
     "args": ["-y", "xcodebuildmcp@latest"]
   }
   ```

2. **Set session defaults** for the project:
   Using the MCP tool `session-set-defaults`:
   ```
   projectPath: ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj
   scheme: MusicStoryRenderer
   simulatorName: iPhone 16
   useLatestOS: true
   ```

3. **Validate build workflow**:
   - `build_sim` should build the app successfully
   - `get_sim_app_path` should return the built .app path

4. **Validate test workflow**:
   - `test_sim` should run tests and report results

5. **Validate run workflow**:
   - `boot_sim` should boot the simulator
   - `build_run_sim` should build and launch the app
   - `screenshot` should capture the running app
   - `describe_ui` should return the view hierarchy

6. **Document MCP usage** in `ios/AGENTS.md`:
   ```markdown
   ## XcodeBuildMCP Usage
   
   Before using XcodeBuildMCP tools, set session defaults:
   - Project: ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj
   - Scheme: MusicStoryRenderer
   - Simulator: iPhone 16
   
   Common tools:
   - `build_sim` - Build for simulator
   - `test_sim` - Run tests
   - `build_run_sim` - Build and launch app
   - `screenshot` - Capture simulator screen
   - `describe_ui` - Get view hierarchy for automation
   ```

## Notes

- XcodeBuildMCP requires the Xcode project to exist; run `xcodegen generate` first.
- The simulator must be installed (TASK-13.2) for these tools to work.
- Some tools like `describe_ui` require Facebook IDB for full functionality.

## Acceptance Criteria

- [ ] XcodeBuildMCP can discover the project
- [ ] Session defaults are documented
- [ ] `build_sim` succeeds
- [ ] `test_sim` runs tests
- [ ] `build_run_sim` launches the app
- [ ] MCP workflow documented in `ios/AGENTS.md`
<!-- SECTION:DESCRIPTION:END -->
