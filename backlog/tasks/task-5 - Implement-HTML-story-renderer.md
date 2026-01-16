---
id: task-5
title: Implement HTML story renderer
status: Done
assignee: []
created_date: '2026-01-12 18:48'
updated_date: '2026-01-15 21:48'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the HTML renderer described in doc-3 (HTML Story Renderer Spec), including MusicKit JS authorization, shared playback queue, and global playback controls.

Implementation plan:
1. Build renderer core: parse MDX, render HTML templates, map Section/MediaRef blocks.
2. Add MusicKit JS authorization flow for developer + user tokens.
3. Wire media cards to a shared queue and global playback bar.
4. Implement server mode story browser.
5. Implement static HTML export.

Subtasks:
- task-6: Build story renderer core.
- task-7: Add MusicKit JS authorization.
- task-8: Wire playback queue + global controls.
- task-9: Implement server mode story browser.
- task-10: Implement static HTML export.

Notes:
- Inputs: story.mdx packages under stories/ and examples/.
- Outputs: standalone HTML export and a story listing server.
- Use scripts/validate_story.py for schema checks.

Acceptance criteria:
- Sample story renders to a magazine-like HTML page.
- Media cards enqueue and control playback through a shared MusicKit JS queue.
- Global playback controls reflect the current track and queue state.
- Server lists available stories and serves rendered HTML routes.
- Static export outputs index.html with assets.
<!-- SECTION:DESCRIPTION:END -->
