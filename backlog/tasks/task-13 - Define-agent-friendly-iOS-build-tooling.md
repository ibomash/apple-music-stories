---
id: task-13
title: Define agent-friendly iOS build tooling
status: Later
assignee: []
created_date: '2026-01-17 05:56'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define a CLI-driven build/test workflow for the iOS app that minimizes reliance on Xcode UI, including formatting, linting, and test automation.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Audit CLI tooling options (xcodebuild, SwiftPM, fastlane, make).
- Choose automation approach and script entrypoints.
- Decide formatter and linter tooling.
- Establish test command and simulator target.
- Document commands in AGENTS.md.
<!-- SECTION:PLAN:END -->
