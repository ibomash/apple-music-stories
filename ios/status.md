# iOS Status

## Phase Summary
- Phase 1 (Story parsing + static rendering): Done
- Phase 2 (Media cards + queue state): Done
- Phase 3 (MusicKit integration + playback bar): Done
- Phase 4 (Story picker + local bundle ingestion): Done

## Current Task Order
1. TASK-35 - Add iOS UI snapshot + diagnostics banner tests

## Notes
- Story renderer includes a playlist creation CTA for story media.
- Linux: focus on SwiftPM core tests, docs, and fixtures; UI changes still require macOS validation.
- macOS: create the Xcode project, configure signing/MusicKit capability, and run simulator/device builds.
- TASK-31 should land before or alongside TASK-26 so device testing can validate Apple Music playback.
- Diagnostics banner snapshots depend on the banner UI landing; keep TASK-35 flexible until the banner exists.
