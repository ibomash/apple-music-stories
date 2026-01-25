---
id: TASK-99
title: Add Rick Astley magazine story + iOS test
status: Done
assignee: []
created_date: '2026-01-25 03:47'
updated_date: '2026-01-25 03:54'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a built-in story about Rick Astley's 'Never Gonna Give You Up' using all magazine MDX elements and ensure iOS tests validate rendering.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Locate built-in stories and add a new story folder with MDX
- Fill frontmatter with accentColor, heroGradient, deck, typeRamp, leadArt
- Include DropQuote, SideNote, FeatureBox, FactGrid, Timeline, Gallery, FullBleed blocks
- Update iOS tests/fixtures to assert blocks parse and render
- Run SwiftPM and Xcode simulator tests
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added built-in Rick Astley story with new magazine elements and Apple Music IDs. Added iOS app test RickAstleyStoryTests to verify all block types and metadata parse. Ran python scripts/validate_story.py for new story, ./scripts/ios.sh swift-test, and XcodeBuildMCP_test_sim (pass; Bundle Stories warning).
<!-- SECTION:NOTES:END -->
