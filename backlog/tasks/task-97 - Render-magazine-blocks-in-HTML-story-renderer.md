---
id: TASK-97
title: Render magazine blocks in HTML story renderer
status: Later
assignee: []
created_date: '2026-01-24 22:13'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Update the HTML renderer to support DropQuote, SideNote, FeatureBox, FactGrid/Fact, Timeline/TimelineItem, Gallery/GalleryImage, and FullBleed blocks plus new frontmatter styling hints (accentColor, heroGradient, deck, typeRamp, leadArt).
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extend HTML MDX parser mapping for new components
- Add HTML/CSS templates for each block with graceful fallbacks
- Add tests or fixtures for new components
<!-- SECTION:PLAN:END -->
