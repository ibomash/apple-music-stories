import XCTest
@testable import MusicStoryRendererCore

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

    private func makeStory(body: String) -> String {
        """
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
          - key: trk-1
            type: track
            apple_music_id: "123"
            title: "Song"
            artist: "Artist"
        ---
        \(body)
        """
    }
}
