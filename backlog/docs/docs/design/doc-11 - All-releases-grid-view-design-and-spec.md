---
id: doc-11
title: All Releases Grid View Design and Spec
type: spec
created_date: '2026-02-15 10:00'
---

## Design Brief (Magazine Direction)

### Intent
Add a dedicated all-releases view inside each story so readers can browse every album, track, video, and playlist from one place without hunting through the narrative.

### Editorial Vibe
- Keep the page feeling like a music magazine feature, not a utility dashboard.
- Use a strong section opener, concise deck copy, and tactile cards that echo existing print-inspired spacing and typography.
- Make release type obvious at a glance with bold type badges and distinct visual treatment for album, track, and video.

### Reader Outcome
- A reader can scan the complete catalog in one pass.
- A reader can narrow quickly to albums, tracks, videos, or playlists.
- A reader can understand chronology from release-date ordering and explicit date labels on each card.

### Experience Principles
- **Immediate context:** title + deck explain what the grid is and why it exists.
- **Fast wayfinding:** one-click filters (All, Albums, Tracks, Videos, Playlists).
- **Chronological trust:** cards sorted by release date (oldest to newest), with missing dates clearly marked.
- **Type clarity:** badge + color treatment + filter labels reinforce release kind.

## Detailed Spec

### Scope
Add a new story-level section named **All Releases** to the HTML renderer output in `scripts/render_story.py`.

### Data Contract
- Extend parsed media model with optional `release_date` string in `YYYY`, `YYYY-MM`, or `YYYY-MM-DD` formats.
- Preserve backward compatibility: stories without `release_date` continue to render.

### Included Media Types
- Included: `album`, `track`, `music-video` (and normalized `video` alias), and `playlist`.
- Excluded: unsupported types.

### Ordering Rules
- Sort order is ascending by parsed `release_date`.
- Parsed date granularity handling:
  - `YYYY` -> treated as January 1st of year.
  - `YYYY-MM` -> treated as first day of month.
  - `YYYY-MM-DD` -> exact day.
- Items with missing/invalid dates render after dated items, then alphabetically by title.

### UI Structure
- Place new view at top of `<main class="container">` before story sections.
- Section markup includes:
  - heading and short deck.
  - filter controls (`All`, `Albums`, `Tracks`, `Videos`, `Playlists`).
  - responsive card grid.
- Reuse existing media-card rendering and playback hooks to avoid duplicate interaction logic.

### Visual Requirements
- Preserve current magazine type system and palette.
- Add release-grid-specific layout styling:
  - responsive multi-column grid on desktop.
  - single-column cards on small screens.
  - compact card metadata row for release date.
- Keep release type signaling explicit via badge classes and labels.

### Behavior
- Filter buttons toggle card visibility in-place (client-side, no reload).
- Active filter is visually distinct.
- Playback controls remain available on non-video cards, matching current behavior.

### Accessibility
- Filters implemented as semantic `<button>` elements.
- Toggle state exposed via `aria-pressed`.
- Date fallback text uses explicit label (`Release date unknown`).

### Testing Requirements
- Add renderer unit tests to verify:
  - sorting by `release_date` ascending.
  - playlist exclusion from all-releases grid.
  - filter controls and release-type badges are present.

### Acceptance Criteria
- Each rendered story includes one all-releases grid view.
- Grid contains all albums/tracks/videos in chronological order.
- Grid contains all albums/tracks/videos/playlists in chronological order.
- Release type is clearly labeled on every card.
- Filtering buttons function without breaking playback controls.
- New tests pass in local test run.
