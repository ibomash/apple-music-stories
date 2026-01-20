# iOS Development

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
