---
id: TASK-50
title: Fix SwiftPM unhandled file warnings
status: Later
assignee: []
created_date: '2026-01-21 00:16'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
SwiftPM warns that ios/MusicStoryRenderer includes unhandled files (Signing.xcconfig, Signing.xcconfig.example, Info.plist, project.yml) when running `swift test`. Triage whether these should be excluded, moved, or declared as resources to keep the package test output clean.

Acceptance Criteria
- [ ] `swift test` no longer warns about unhandled files in ios/MusicStoryRenderer
- [ ] Package configuration documents any required exclusions/resources
<!-- SECTION:DESCRIPTION:END -->
