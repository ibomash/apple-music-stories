# iOS Development

## Agent-Friendly Build Tooling (Target Plan)

The iOS app uses an **XcodeGen + XcodeBuildMCP** workflow to enable autonomous agent-driven development. This approach keeps the Xcode project reproducible, avoids manual `.xcodeproj` edits, and integrates with MCP tools for CLI build/test/run cycles.

### Architecture

```
ios/MusicStoryRenderer/
├── project.yml              # XcodeGen spec (committed)
├── MusicStoryRenderer.xcodeproj/  # Generated (gitignored)
├── Package.swift            # SwiftPM for core library tests
├── App/                     # SwiftUI app entry point
├── Models/                  # Domain models
├── Playback/                # MusicKit integration
├── Rendering/               # SwiftUI views
├── StoryParser.swift        # MDX parser
├── StoryPackageLoader.swift # Package loader
├── StoryDocumentStore.swift # State management
└── Tests/                   # Core library tests
```

### Workflow

Default simulator: iPhone 17

1. **Project generation**: Run `xcodegen generate` from `ios/MusicStoryRenderer` after structure changes. The generated `.xcodeproj` is gitignored.

2. **Core library tests** (any platform with Swift): `swift test` from `ios/MusicStoryRenderer`.

3. **App build/test** (macOS only):
   ```bash
   cd ios/MusicStoryRenderer
   xcodegen generate
    xcodebuild -project MusicStoryRenderer.xcodeproj \
      -scheme MusicStoryRenderer \
      -destination "platform=iOS Simulator,name=DEFAULT_SIMULATOR" \
      build
    xcodebuild test -project MusicStoryRenderer.xcodeproj \
      -scheme MusicStoryRenderer \
      -destination "platform=iOS Simulator,name=DEFAULT_SIMULATOR"
   ```

### Snapshot tests

Run the snapshot suite with deterministic settings baked into the tests (en_US locale, GMT time zone, medium dynamic type size, light mode).

Record baselines:
```bash
cd ios/MusicStoryRenderer
SNAPSHOT_RECORDING=1 xcodebuild test -project MusicStoryRenderer.xcodeproj \
  -scheme MusicStoryRenderer \
  -destination "platform=iOS Simulator,name=DEFAULT_SIMULATOR"
```

Verify baselines:
```bash
cd ios/MusicStoryRenderer
xcodebuild test -project MusicStoryRenderer.xcodeproj \
  -scheme MusicStoryRenderer \
  -destination "platform=iOS Simulator,name=DEFAULT_SIMULATOR"
```

4. **Agent builds**: Use XcodeBuildMCP tools after generating the project and setting session defaults. Example flow:
   ```
   XcodeBuildMCP_discover_projs workspaceRoot="/Users/ibomash/repos-ibomash/apple-music-stories/ios"
   XcodeBuildMCP_session-set-defaults projectPath="/Users/ibomash/repos-ibomash/apple-music-stories/ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj" scheme="MusicStoryRenderer" useLatestOS=true
   XcodeBuildMCP_list_sims
   XcodeBuildMCP_session-set-defaults simulatorId="SIMULATOR_UDID"
   XcodeBuildMCP_build_sim
   XcodeBuildMCP_test_sim
   XcodeBuildMCP_get_sim_app_path platform="iOS Simulator"
   XcodeBuildMCP_get_app_bundle_id appPath="PATH_FROM_GET_SIM_APP_PATH"
   XcodeBuildMCP_launch_app_sim bundleId="BUNDLE_ID_FROM_GET_APP_BUNDLE_ID"
   ```

### Simulator alignment checks

Use this when validating story layout width and hero image alignment.

1. Build and run on the current simulator:
   ```
   XcodeBuildMCP_build_run_sim
   ```
2. Open the story URL from the landing screen:
   - Call `XcodeBuildMCP_describe_ui` to find the `Load from URL` button frame.
   - Tap the `Load from URL` button with `XcodeBuildMCP_tap`.
   - Call `XcodeBuildMCP_describe_ui` again to get the text field frame.
   - Tap the text field center and type the URL (for example `https://bomash.net/story.mdx`).
   - Tap the `Load Story` button.
3. Validate alignment in the story view:
   - Call `XcodeBuildMCP_describe_ui` and note the top-level app frame width.
   - Look for the hero image/artwork element and confirm its `x` position is not negative and its width does not exceed the screen width.
   - Optionally capture a screenshot with `XcodeBuildMCP_screenshot` for visual confirmation.

### Key Files

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen spec defining targets, capabilities, entitlements |
| `MusicStoryRenderer.entitlements` | MusicKit entitlement |
| `.swiftlint.yml` | (optional) Lint rules |
| `.swiftformat` | (optional) Format rules |

### Setup Requirements

- **macOS**: Xcode 26.2+, XcodeGen (`brew install xcodegen`), iOS simulator runtime
- **Linux**: Swift 6.2 via swiftenv (core library tests only)
- **MCP servers**: XcodeBuildMCP and Apple Docs MCP configured in agent environment

---

## Linux responsibilities
- Work on the SwiftPM core in `ios/MusicStoryRenderer` (parser, loader, models, tests).
- Initialize swiftenv and run tests from `ios/MusicStoryRenderer`:
  ```bash
  export PATH="$HOME/.swiftenv/bin:$PATH"
  eval "$(swiftenv init -)"
  swift test
  ```
- Update docs and status (`ios/architecture.md`, `ios/status.md`) as work progresses.
- Keep sample story fixtures current (for example `examples/sample-story/story.mdx`).
- UI changes can be made here, but validation still requires macOS/Xcode.

## macOS responsibilities
- Create an Xcode project/workspace for the app under `ios/MusicStoryRenderer` and add all app sources.
- Configure signing/provisioning and enable the MusicKit capability.
- Add `NSAppleMusicUsageDescription` to the app Info.plist.
- Bundle `examples/sample-story/story.mdx` as `sample-story.mdx` for the initial launch flow.
- Run the app on simulator/device and validate Apple Music playback.
- Run UI snapshot tests (TASK-35) once the snapshot suite is in place.

## Development rules
- This repo targets Swift 6.2 and Python 3.13.
- Always run relevant tests for changes. If tests cannot run, note the blocker.
- Keep secrets out of the repo; store Apple Music tokens in local-only configs.
- Follow `AGENTS.md` for Backlog/Beads task creation and workflow guidance.
- Keep `ios/architecture.md` and `ios/status.md` up to date as tasks move.
