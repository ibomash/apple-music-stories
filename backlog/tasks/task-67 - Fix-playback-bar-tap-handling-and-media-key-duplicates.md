---
id: TASK-67
title: Fix playback bar tap handling and media key duplicates
status: Done
assignee: []
created_date: '2026-01-23 14:12'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Address code review issues: make the playback bar play/pause control tappable (avoid nested Button handling) and handle duplicate media keys safely (validate or unique) so rendering doesn't crash.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Update playback bar tap handling to avoid nested Buttons.
- Prevent crashes from duplicate media keys during parsing/lookup.
- Run relevant tests (or note blockers).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Updated playback bar tap handling to avoid nested Button taps.
- Added duplicate media key validation and safe mediaByKey construction.
- Added StoryParser test for duplicate media keys.
- Tests: swift test (warns about unhandled SwiftPM files: Info.plist, project.yml, Config/Signing.xcconfig.example, Config/Signing.xcconfig).
<!-- SECTION:NOTES:END -->
