---
id: doc-8
title: Story card accent tint spec
type: feature
created_date: '2026-01-25 15:41'
---

## Summary
- Add a subtle accent tint to each story card background on the iOS main screen.
- Tint should be noticeable but gentle, preserving text and artwork contrast.

## Visual treatment
- Base: existing card background color remains the base layer.
- Tint: overlay a subtle diagonal gradient using the story accent color.
- Intensity target: ~14% to 24% opacity equivalent across the gradient (tweak for readability).
- Rounding and shadows should remain unchanged.

## Behavior
- Tint applies to all cards on the main screen list/grid.
- Uses the story accent color when available; fallback to existing neutral background.

## Acceptance criteria
- Cards show a consistent, subtle accent tint.
- Text and imagery remain legible and meet existing contrast expectations.
