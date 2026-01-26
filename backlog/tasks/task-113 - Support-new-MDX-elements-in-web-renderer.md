---
id: TASK-113
title: Support new MDX elements in web renderer
status: Done
assignee: []
created_date: '2026-01-25 17:19'
updated_date: '2026-01-25 17:33'
labels:
  - HTML renderer
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ensure every newly introduced MDX element renders correctly in the web/HTML renderer.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All new MDX elements render without fallback warnings.
- [ ] #2 Web renderer output matches authoring expectations for the new elements.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Confirmed HTML renderer already supports all MDX magazine blocks (DropQuote, SideNote, FeatureBox, FactGrid/Fact, Timeline/TimelineItem, Gallery/GalleryImage, FullBleed). Ran render smoke check: uv run scripts/render_story.py stories/rick-astley-never-gonna-give-you-up out/rick-astley (success).
<!-- SECTION:NOTES:END -->
