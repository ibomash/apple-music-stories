# iOS Agent Instructions

Read `ios/architecture.md` for a full overview of the app architecture and playback integration. Keep `ios/architecture.md` and `ios/status.md` updated as the iOS app evolves.

## Swift toolchain setup

When running Swift tooling, ensure swiftenv is initialized first:

```bash
export PATH="$HOME/.swiftenv/bin:$PATH"
eval "$(swiftenv init -)"
```

After this, run Swift commands (for example `swift test`) from `ios/MusicStoryRenderer`.

## Project generation

After adding or removing source files, regenerate the Xcode project:

```bash
cd ios/MusicStoryRenderer
xcodegen generate
```

## Default iOS simulator

Use the iPhone 16 simulator on iOS 26.2 for builds and tests:

```bash
iPhone 16 (com.apple.CoreSimulator.SimDeviceType.iPhone-16)
Runtime: com.apple.CoreSimulator.SimRuntime.iOS-26-2
```

## Build commands

Run these from `ios/MusicStoryRenderer`:

| Command | Platform | Purpose |
| --- | --- | --- |
| `swift test` | Any | Core library tests |
| `xcodebuild -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16" build` | macOS | Full app build |
| `xcodebuild test -project MusicStoryRenderer.xcodeproj -scheme MusicStoryRenderer -destination "platform=iOS Simulator,name=iPhone 16"` | macOS | Run all tests |

## Linting and formatting

Install tooling if needed:

```bash
brew install swiftlint swiftformat
```

Run from `ios/MusicStoryRenderer`:

```bash
swiftlint lint --config .swiftlint.yml
swiftformat --lint .
swiftformat .
```

Helper script from the repo root:

```bash
./scripts/ios.sh generate|build|test|swift-test|lint|format|clean
```

The helper script initializes swiftenv when available and falls back to the system Swift toolchain.

## MCP servers

OpenCode MCP config for Apple Docs is defined at the repo root (`opencode.jsonc`) as `apple_docs` (local: `npx -y apple-doc-mcp-server@latest`). Use it when you need Apple documentation.

## XcodeBuildMCP usage

Before using XcodeBuildMCP tools, set session defaults:

- Project: `ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj`
- Scheme: `MusicStoryRenderer`
- Simulator: `iPhone 16`

Common tools:

- `build_sim` - Build for simulator
- `test_sim` - Run tests
- `build_run_sim` - Build and launch app
- `get_sim_app_path` - Fetch simulator app bundle path
- `get_app_bundle_id` - Resolve bundle identifier
- `launch_app_sim` - Launch the app
- `screenshot` - Capture simulator screen
- `describe_ui` - Get view hierarchy for automation

Example build-fix loop:

```bash
XcodeBuildMCP_discover_projs workspaceRoot="/Users/ibomash/repos-ibomash/apple-music-stories/ios"
XcodeBuildMCP_session-set-defaults projectPath="/Users/ibomash/repos-ibomash/apple-music-stories/ios/MusicStoryRenderer/MusicStoryRenderer.xcodeproj" scheme="MusicStoryRenderer" simulatorName="iPhone 16" useLatestOS=true
XcodeBuildMCP_build_sim
XcodeBuildMCP_test_sim
XcodeBuildMCP_get_sim_app_path platform="iOS Simulator"
XcodeBuildMCP_get_app_bundle_id appPath="PATH_FROM_GET_SIM_APP_PATH"
XcodeBuildMCP_launch_app_sim bundleId="BUNDLE_ID_FROM_GET_APP_BUNDLE_ID"
```

## Safe command allowlist

- `xcodebuild`, `xcodegen`, `xcrun simctl`
- `swift build`, `swift test`
- `swiftlint`, `swiftformat`
- `git status`, `git diff`, `git log`

## Coding conventions

- No force unwraps (`!`).
- MVVM architecture with views separate from view models.
- Prefer async/await for async code.
- Use SwiftUI for all new views.

## Diagnostics

- Default to adding diagnostic logging for new features where there is a logical place to inspect behavior, or ask whether logging should be added when unsure.
