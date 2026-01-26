---
id: TASK-102
title: Fix MusicKit playback test
status: Done
assignee: []
created_date: '2026-01-25 04:16'
updated_date: '2026-01-26 18:01'
labels:
  - HTML renderer
dependencies: []
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate why MusicKit playback does not start in Puppeteer playback test and make it reliable.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Final Fix (2026-01-25)

### Root Cause
In MusicKit v3, `MusicKit.configure()` returns a Promise that resolves to a MusicKit instance, BUT this is NOT the same instance as `MusicKit.getInstance()`. The code was storing the configure() result in `musicInstance`, but the UI button handlers were using `musicInstance` to call play() - which was operating on a different instance than the one MusicKit internally uses.

### The Fix
Changed `render_story.py` line 1007-1010:

Before:
```javascript
musicInstance = await MusicKit.configure({...});
```

After:
```javascript
await MusicKit.configure({...});
musicInstance = MusicKit.getInstance();
```

This ensures `musicInstance` is the actual singleton that MusicKit uses internally.

### Verification
- Puppeteer test passes with playback confirmation
- Button clicks properly trigger setQueue() and play()
- Time counter advances during playback
- All 34 media cards are functional
<!-- SECTION:NOTES:END -->
