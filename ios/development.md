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

1. **Project generation**: Run `xcodegen generate` from `ios/MusicStoryRenderer` after structure changes. The generated `.xcodeproj` is gitignored.

2. **Core library tests** (any platform with Swift): `swift test` from `ios/MusicStoryRenderer`.

3. **App build/test** (macOS only):
   ```bash
   cd ios/MusicStoryRenderer
   xcodegen generate
   xcodebuild -project MusicStoryRenderer.xcodeproj \
     -scheme MusicStoryRenderer \
     -destination "platform=iOS Simulator,name=iPhone 16" \
     build
   ```

4. **Agent builds**: Use XcodeBuildMCP tools (`build_sim`, `test_sim`, `build_run_sim`) after setting session defaults for the project and scheme.

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
- Use the `backlog` CLI to manage tasks and create new ones for non-trivial work.
- Keep `ios/architecture.md` and `ios/status.md` up to date as tasks move.
