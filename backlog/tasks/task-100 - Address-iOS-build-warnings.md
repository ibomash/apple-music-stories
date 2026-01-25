---
id: TASK-100
title: Address iOS build warnings
status: Later
assignee: []
created_date: '2026-01-25 04:05'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Track fixes for SwiftPM unhandled file warnings and the Bundle Stories build script output warning.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Update Package.swift to exclude non-source files (project.yml, Signing.xcconfig, Info.plist) from SwiftPM target
- Add output files for the Bundle Stories build script or mark it to always run
- Re-run swift-test and Xcode simulator tests to confirm warnings are resolved
<!-- SECTION:PLAN:END -->
