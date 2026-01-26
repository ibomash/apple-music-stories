---
id: TASK-40
title: Configure iOS signing and MusicKit
status: Done
assignee: []
created_date: '2026-01-20 02:58'
updated_date: '2026-01-26 18:01'
labels:
  - macOS
dependencies: []
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up signing, enable the MusicKit capability, and add NSAppleMusicUsageDescription in the app project.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Enable the MusicKit capability for the App ID and refresh provisioning profiles.
- Configure signing/provisioning in the Xcode project.
- Add NSAppleMusicUsageDescription to the app Info.plist.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Info.plist includes NSAppleMusicUsageDescription. Per current scope, entitlements/capability are not required for MusicKit; signing steps deferred.
<!-- SECTION:NOTES:END -->
