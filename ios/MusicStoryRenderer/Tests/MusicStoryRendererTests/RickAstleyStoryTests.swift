@testable import MusicStoryRenderer
import XCTest

final class RickAstleyStoryTests: XCTestCase {
    func testBundledRickAstleyStoryContainsAllMagazineBlocks() throws {
        let storyURL = try makeStoryURL()
        let storyText = try String(contentsOf: storyURL, encoding: .utf8)

        let parsed = StoryParser().parse(
            storyText: storyText,
            assetBaseURL: storyURL.deletingLastPathComponent(),
        )

        let errors = parsed.diagnostics.filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty)
        guard let document = parsed.document else {
            return XCTFail("Expected parsed story document")
        }

        XCTAssertEqual(document.id, "rick-astley-never-gonna-give-you-up")
        XCTAssertNotNil(document.deck)
        XCTAssertFalse(document.heroGradient.isEmpty)
        XCTAssertNotNil(document.typeRamp)
        XCTAssertNotNil(document.leadArt)

        let blocks = document.sections.flatMap { $0.blocks }
        XCTAssertTrue(blocks.contains(where: { if case .dropQuote = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .sideNote = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .featureBox = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .factGrid = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .timeline = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .gallery = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .fullBleed = $0 { return true } else { return false } }))
        XCTAssertTrue(blocks.contains(where: { if case .media = $0 { return true } else { return false } }))
    }

    private func makeStoryURL() throws -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            root.deleteLastPathComponent()
        }
        let storyURL = root.appendingPathComponent(
            "stories/rick-astley-never-gonna-give-you-up/story.mdx",
        )
        if !FileManager.default.fileExists(atPath: storyURL.path) {
            throw NSError(domain: "StoryFileMissing", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing Rick Astley story at \(storyURL.path)",
            ])
        }
        return storyURL
    }
}
