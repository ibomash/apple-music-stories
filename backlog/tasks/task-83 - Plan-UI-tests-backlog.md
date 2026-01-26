---
id: TASK-83
title: Plan UI tests backlog
status: Next
assignee: []
created_date: '2026-01-23 22:29'
updated_date: '2026-01-26 03:50'
labels: []
dependencies: []
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Collect UI test coverage needed for the iOS app, including story deletion from Available Stories.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Planned UI test coverage:\n- Available Stories: long-press non-bundled story card -> Delete Story -> confirm removal from list.\n- Current Story: tap "Open Story" -> story detail view shows title.\n- Available Stories: tap catalog card -> navigates to detail view.\n- Load from URL sheet: disabled Load Story until input; invalid URL shows "Enter a valid URL."; invalid scheme shows http/https error; invalid extension shows .mdx error; cancel dismisses.\n- Saved URL story: delete from Current Story confirmation -> returns to idle and removes saved section.\n- Recent local story: delete from Available Stories -> removal from list.\n- Diagnostics: appears on load failure/warning with at least one row.\n- Playback bar: Play media -> playback bar appears and shows track/artist text.\n- Now Playing: open sheet from playback bar; Done dismisses.\n- Media card variants: audio shows Play/Queue; music video shows "Play Video in Music app" only.\n- Queue status: Queue action updates badge to "Queued" and label changes.\n- Story actions menu: Create story playlist action exists; after start, Cancel appears.\n- Story playlist CTA: Create -> progress text shows; Cancel -> failure message.\n- Scroll bookmark: scroll to section, back out, reopen same story -> restored position visible.\n\nNote: Some tests may need added accessibility identifiers for stable selectors (story cards, delete buttons, playlist CTA, diagnostics rows).
<!-- SECTION:NOTES:END -->
