---
id: TASK-96
title: Render magazine blocks in iOS story renderer
status: Later
assignee: []
created_date: '2026-01-24 22:13'
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
