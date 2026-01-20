# iOS agent instructions

Read `ios/architecture.md` for a full overview of the app architecture and playback integration. Keep `ios/architecture.md` updated as the iOS app evolves. Also check `ios/status.md` for current phase status and keep it updated as tasks move.

## Swift toolchain setup

When running Swift tooling, ensure swiftenv is initialized first:

```bash
export PATH="$HOME/.swiftenv/bin:$PATH"
eval "$(swiftenv init -)"
```

After this, run Swift commands (e.g., `swift test`) from `ios/MusicStoryRenderer`.

## Default iOS simulator

Use the iPhone 16 simulator on iOS 26.2 for builds and tests:

```bash
iPhone 16 (com.apple.CoreSimulator.SimDeviceType.iPhone-16)
Runtime: com.apple.CoreSimulator.SimRuntime.iOS-26-2
```

## MCP servers

OpenCode MCP config for Apple Docs is defined at the repo root (`opencode.jsonc`) as `apple_docs` (local: `npx -y apple-doc-mcp-server@latest`). Use it when you need Apple documentation.
