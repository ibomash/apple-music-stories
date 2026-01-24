# Music Stories app icon

## Overview
The icon represents a music story card with an overlaid play disc. It combines an editorial, calm reading surface (paper card) with a warm playback cue (coral disc + play glyph) over a deep night-sky background.

## Source files
- `MusicStories-AppIcon.svg`: master composite SVG (single file).
- `MusicStories-AppIcon.html`: preview + export tool (renders the SVG and downloads PNGs).
- `layers/`: individual layer SVGs for Icon Composer or Liquid Glass workflows.

## Layer breakdown
1. Background: gradient base + glow/vignette.
2. Card depth: subtle offset paper shadow block.
3. Card: main story card surface.
4. Card highlight: soft top sheen.
5. Text: three hint lines.
6. Disc: playback disc + highlight + play glyph.

## How it was made
1. Updated the master SVG by hand for balanced spacing, depth, and readability.
2. Generated a preview PNG via `rsvg-convert`.
3. Split the composite into separate layer SVGs for Apple Icon Composer.

## Notes
- Ignore `MusicStories-AppIcon-preview.png` (preview-only artifact).
