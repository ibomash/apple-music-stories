---
id: TASK-74
title: Add music video playback in iOS app
status: Done
assignee: []
created_date: '2026-01-23 18:12'
updated_date: '2026-01-26 18:01'
labels: []
dependencies: []
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enable story media entries of type musicVideo to play video content inside the iOS renderer rather than raising an unsupported error.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add MusicKit lookup for MusicVideo (MusicCatalogResourceRequest<MusicVideo>) and build a queue entry for musicVideo media in AppleMusicPlaybackController.makeQueue instead of throwing unsupportedMedia.
- Decide playback mode per intent:
  - Preview: load MusicVideo.previewAssets URL and play with AVPlayer/VideoPlayer.
  - Full: use SystemMusicPlayer (or ApplicationMusicPlayer if full-screen playback is needed) with MusicVideo in the queue.
- Add a VideoPlaybackView (UIViewControllerRepresentable with AVPlayerViewController) that forces landscape-capable orientations while presented.
- Surface video playback in the UX:
  - Media cards: replace static artwork with a video thumbnail and "Play Video" action for musicVideo media.
  - Now Playing sheet: swap the artwork block for the embedded VideoPlaybackView when the current media type is musicVideo.
  - Present video full-screen (fullScreenCover) to allow rotation and horizontal playback.
- Update playback metadata/queue to keep musicVideo entries visible in the playback bar and sheet.
- Add tests to cover MusicVideo parsing, queueing, and playback intent routing (preview vs full).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
UX approach: play music videos in a full-screen video surface that supports landscape orientation. The media card and Now Playing sheet should detect StoryMediaType.musicVideo and show video-specific controls (Play Video, Queue Video). When a video is active, present a fullScreenCover with a VideoPlaybackView backed by AVPlayerViewController, configured to allow landscape and to auto-rotate when the user turns the device. This avoids cramping the story layout while still keeping the playback bar visible for audio-only content.

Tech notes: StoryMediaType already supports musicVideo, but AppleMusicPlaybackController.makeQueue currently throws unsupportedMedia. Use MusicCatalogResourceRequest<MusicVideo> for catalog lookup. For previews, use MusicVideo.previewAssets to feed AVPlayer. For full playback, queue MusicVideo in SystemMusicPlayer (or ApplicationMusicPlayer if a dedicated video surface is required).

Refs: ios/MusicStoryRenderer/Playback/AppleMusicPlaybackController.swift; ios/MusicStoryRenderer/App/MusicStoryRendererApp.swift; ios/MusicStoryRenderer/Rendering/StoryRendererView.swift.

Implementation: music videos now route through AVPlayer preview playback with a full-screen VideoPlaybackView. The playback controller treats music videos as a video target (preview URL from MusicKit), while audio items continue to use SystemMusicPlayer. Now Playing exposes a Show Video action, and media cards label actions as Play/Queue Video.
Note: MusicVideo items are not playable via MusicKit queues, so full in-app playback is driven by preview assets.
<!-- SECTION:NOTES:END -->
