@testable import MusicStoryRendererCore
import XCTest

final class StoryParserTests: XCTestCase {
    func testParsesValidStory() {
        let story = makeStory(body: """
        <Section id=\"intro\" title=\"Intro\" layout=\"lede\">
        The signal flickers into focus.

        <MediaRef ref=\"trk-1\" intent=\"preview\" />
        </Section>
        """)

        let parsed = StoryParser().parse(storyText: story, assetBaseURL: nil)

        XCTAssertNotNil(parsed.document)
        XCTAssertTrue(parsed.diagnostics.isEmpty)
        XCTAssertEqual(parsed.document?.sections.count, 1)
        XCTAssertEqual(parsed.document?.media.count, 1)
        XCTAssertEqual(parsed.document?.sections.first?.layout, "lede")
        XCTAssertEqual(parsed.document?.sections.first?.blocks.count, 2)
    }

    func testReportsMissingFrontMatter() {
        let parsed = StoryParser().parse(storyText: "No front matter", assetBaseURL: nil)

        XCTAssertNil(parsed.document)
        XCTAssertTrue(parsed.diagnostics.contains { $0.code == "missing_front_matter" })
    }

    func testWarnsOnInvalidLayout() {
        let story = makeStory(body: """
        <Section id=\"intro\" title=\"Intro\" layout=\"banner\">
        Hello.
        </Section>
        """)

        let parsed = StoryParser().parse(storyText: story, assetBaseURL: nil)

        XCTAssertNotNil(parsed.document)
        XCTAssertTrue(parsed.diagnostics.contains { $0.code == "invalid_layout" })
        XCTAssertEqual(parsed.document?.sections.first?.layout, "body")
    }

    func testInvalidIntentDefaultsToPreview() {
        let story = makeStory(body: """
        <Section id=\"intro\" title=\"Intro\">
        <MediaRef ref=\"trk-1\" intent=\"surprise\" />
        </Section>
        """)

        let parsed = StoryParser().parse(storyText: story, assetBaseURL: nil)

        XCTAssertTrue(parsed.diagnostics.contains { $0.code == "invalid_intent" })
        guard let document = parsed.document else {
            return XCTFail("Expected document")
        }
        guard case let .media(_, _, intent) = document.sections.first?.blocks.first else {
            return XCTFail("Expected media block")
        }
        XCTAssertEqual(intent, .preview)
    }

    func testReportsTextOutsideSections() {
        let story = makeStory(body: """
        Leading text.
        <Section id=\"intro\" title=\"Intro\">
        Hello.
        </Section>
        """)

        let parsed = StoryParser().parse(storyText: story, assetBaseURL: nil)

        XCTAssertNil(parsed.document)
        XCTAssertTrue(parsed.diagnostics.contains { $0.code == "text_outside_section" })
    }

    func testReportsDuplicateMediaKeys() {
        let story = makeStory(
            body: """
            <Section id=\"intro\" title=\"Intro\" layout=\"lede\">
            Hello.

            <MediaRef ref=\"trk-1\" intent=\"preview\" />
            </Section>
            """,
            media: """
              - key: trk-1
                type: track
                apple_music_id: "123"
                title: "Song"
                artist: "Artist"
              - key: trk-1
                type: track
                apple_music_id: "456"
                title: "Song Two"
                artist: "Artist Two"
            """,
        )

        let parsed = StoryParser().parse(storyText: story, assetBaseURL: nil)

        XCTAssertNil(parsed.document)
        XCTAssertTrue(parsed.diagnostics.contains { $0.code == "duplicate_media_key" })
    }

    func testParsesMagazineBlocks() {
        let story = makeStory(body: """
        <Section id=\"intro\" title=\"Intro\" layout=\"lede\">
        Opening paragraph.

        <DropQuote attribution=\"Prince\">Purple rain.</DropQuote>
        <SideNote label=\"Context\">Blog era footnote.</SideNote>
        <FeatureBox title=\"Box\" summary=\"Summary\" expandable=\"true\">Details.</FeatureBox>
        <FactGrid>
          <Fact label=\"Albums\" value=\"15\" />
        </FactGrid>
        <Timeline>
          <TimelineItem year=\"1984\">Purple Rain drops.</TimelineItem>
        </Timeline>
        <Gallery>
          <GalleryImage src=\"assets/one.jpg\" alt=\"Alt\" caption=\"Cap\" />
        </Gallery>
        <FullBleed src=\"assets/full.jpg\" alt=\"Full\" caption=\"Cap\" kind=\"image\" />
        </Section>
        """)

        let parsed = StoryParser().parse(storyText: story, assetBaseURL: nil)

        XCTAssertNotNil(parsed.document)
        guard let blocks = parsed.document?.sections.first?.blocks else {
            return XCTFail("Expected blocks")
        }
        XCTAssertEqual(blocks.count, 8)
        XCTAssertTrue(blocks.contains(where: { if case .dropQuote = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .sideNote = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .featureBox = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .factGrid = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .timeline = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .gallery = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .fullBleed = $0 { return true } else { return false } }))
    }

    private func makeStory(body: String, media: String? = nil) -> String {
        let mediaBlock = media ?? """
          - key: trk-1
            type: track
            apple_music_id: "123"
            title: "Song"
            artist: "Artist"
        """
        return """
        ---
        schema_version: 0.1
        id: "sample-story"
        title: "Sample Story"
        authors: ["Tester"]
        publish_date: "2026-01-12"
        sections:
          - id: intro
            title: "Intro"
        media:
        \(mediaBlock)
        ---
        \(body)
        """
    }
}

final class PlaybackQueueStateTests: XCTestCase {
    func testQueueAddsUpNextEntry() {
        var state = PlaybackQueueState()
        let media = makeMedia(key: "trk-1")

        state.enqueue(media: media, intent: .full)

        XCTAssertEqual(state.upNext.count, 1)
        XCTAssertEqual(state.status(for: media), .queued)
    }

    func testPlayUsesPreviewIntentByDefault() {
        var state = PlaybackQueueState()
        let media = makeMedia(key: "trk-2")

        state.play(media: media, intent: nil)

        XCTAssertEqual(state.nowPlaying?.intent, .preview)
        XCTAssertEqual(state.status(for: media), .playing)
    }

    func testPlayRemovesFromUpNext() {
        var state = PlaybackQueueState()
        let media = makeMedia(key: "trk-3")

        state.enqueue(media: media, intent: .preview)
        state.play(media: media, intent: .full)

        XCTAssertEqual(state.status(for: media), .playing)
        XCTAssertTrue(state.upNext.isEmpty)
    }

    func testQueueIgnoresNowPlaying() {
        var state = PlaybackQueueState()
        let media = makeMedia(key: "trk-4")

        state.play(media: media, intent: .preview)
        state.enqueue(media: media, intent: .preview)

        XCTAssertTrue(state.upNext.isEmpty)
    }

    func testQueueIgnoresDuplicateEntries() {
        var state = PlaybackQueueState()
        let media = makeMedia(key: "trk-5")

        state.enqueue(media: media, intent: .full)
        state.enqueue(media: media, intent: .preview)

        XCTAssertEqual(state.upNext.count, 1)
    }

    private func makeMedia(key: String) -> StoryMediaReference {
        StoryMediaReference(
            key: key,
            type: .track,
            appleMusicId: "123",
            title: "Song",
            artist: "Artist",
            artworkURL: nil,
            durationMilliseconds: 200_000,
        )
    }
}

final class PlaybackAuthorizationStatusTests: XCTestCase {
    func testAuthorizationAllowsPlaybackOnlyWhenAuthorized() {
        XCTAssertFalse(PlaybackAuthorizationStatus.notDetermined.allowsPlayback)
        XCTAssertFalse(PlaybackAuthorizationStatus.denied.allowsPlayback)
        XCTAssertFalse(PlaybackAuthorizationStatus.restricted.allowsPlayback)
        XCTAssertTrue(PlaybackAuthorizationStatus.authorized.allowsPlayback)
    }

    func testAuthorizationActionTitles() {
        XCTAssertEqual(PlaybackAuthorizationStatus.authorized.actionTitle, "Apple Music Ready")
        XCTAssertEqual(PlaybackAuthorizationStatus.denied.actionTitle, "Sign in to Apple Music")
        XCTAssertEqual(PlaybackAuthorizationStatus.notDetermined.actionTitle, "Sign in to Apple Music")
        XCTAssertEqual(PlaybackAuthorizationStatus.restricted.actionTitle, "Apple Music Restricted")
    }
}

final class PlaybackNowPlayingMetadataTests: XCTestCase {
    func testMetadataMirrorsStoryMedia() {
        let artworkURL = URL(string: "https://example.com/art.jpg")
        let media = StoryMediaReference(
            key: "trk-1",
            type: .track,
            appleMusicId: "123",
            title: "Song",
            artist: "Artist",
            artworkURL: artworkURL,
            durationMilliseconds: 200_000,
        )

        let metadata = PlaybackNowPlayingMetadata(media: media)

        XCTAssertEqual(metadata.title, "Song")
        XCTAssertEqual(metadata.subtitle, "Artist")
        XCTAssertEqual(metadata.artworkURL, artworkURL)
        XCTAssertEqual(metadata.appleMusicId, "123")
        XCTAssertEqual(metadata.type, .track)
    }
}
