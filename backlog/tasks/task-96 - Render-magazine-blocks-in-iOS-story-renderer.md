---
id: TASK-96
title: Render magazine blocks in iOS story renderer
status: Done
assignee: []
created_date: '2026-01-24 22:13'
updated_date: '2026-01-25 03:36'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update the iOS MDX parser and SwiftUI views to support DropQuote, SideNote, FeatureBox, FactGrid/Fact, Timeline/TimelineItem, Gallery/GalleryImage, and FullBleed blocks plus new frontmatter styling hints (accentColor, heroGradient, deck, typeRamp, leadArt).
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extend StoryParser to parse new components and frontmatter fields
- Add SwiftUI views for each block with iOS-friendly layout
- Add renderer fallbacks for missing/invalid attributes
- Add parser and rendering tests
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Updated StoryDocument model, StoryParser, and StoryRendererView to support new frontmatter fields and magazine blocks. Added parsing helpers for DropQuote, SideNote, FeatureBox, FactGrid/Fact, Timeline/TimelineItem, Gallery/GalleryImage, and FullBleed, plus new StoryParserTests coverage. Ran ./scripts/ios.sh swift-test (ok, with existing SwiftPM unhandled file warning). Xcode MCP test_sim failed because MusicStoryRenderer.xcodeproj is missing; xcodegen generate failed due to missing Config/Signing.xcconfig.

Copied Config/Signing.xcconfig from main worktree and generated Xcode project with xcodegen. XcodeBuildMCP_test_sim now passes (warnings about deprecated onChange, AppIntents metadata, Bundle Stories script).
<!-- SECTION:NOTES:END -->
