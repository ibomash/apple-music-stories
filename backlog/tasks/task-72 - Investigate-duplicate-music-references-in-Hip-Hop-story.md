---
id: TASK-72
title: Investigate duplicate music references in Hip-Hop story
status: Done
assignee: []
created_date: '2026-01-23 17:37'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Determine why some music references (e.g., So Far Gone in 2009–2011 section) appear multiple times in the iOS story view, and identify whether the duplication is in the story MDX or in the renderer.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Findings: In stories/hip-hop-changed-the-game/story.mdx the section "2009–2011: New Voices, New Rules" has lead_media: alb-so-far-gone in frontmatter and also a <MediaRef ref="alb-so-far-gone" /> block in the section body. StoryRendererView renders lead_media at the top of each section (see StorySectionView), then renders all MediaRef blocks, so the album appears twice. This duplication is content-driven, not a renderer bug.
<!-- SECTION:NOTES:END -->
