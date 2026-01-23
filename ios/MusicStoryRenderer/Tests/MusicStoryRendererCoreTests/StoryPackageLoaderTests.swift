@testable import MusicStoryRendererCore
import XCTest

final class StoryPackageLoaderTests: XCTestCase {
    func testLoadsStoryFromDirectory() throws {
        let tempDir = try makeTempDirectory()
        let storyURL = tempDir.appendingPathComponent("story.mdx")
        try sampleStory.write(to: storyURL, atomically: true, encoding: .utf8)

        let loader = StoryPackageLoader()
        let package = try loader.loadStory(at: tempDir)

        XCTAssertEqual(package.storyURL, storyURL)
        XCTAssertTrue(package.storyText.contains("schema_version"))
        XCTAssertEqual(package.assetBaseURL.standardizedFileURL.path, tempDir.standardizedFileURL.path)
    }

    func testThrowsForMissingStoryFile() throws {
        let tempDir = try makeTempDirectory()

        let loader = StoryPackageLoader()

        XCTAssertThrowsError(try loader.loadStory(at: tempDir)) { error in
            guard case StoryPackageLoaderError.missingStoryFile = error else {
                return XCTFail("Expected missingStoryFile error")
            }
        }
    }

    private func makeTempDirectory() throws -> URL {
        let baseURL = FileManager.default.temporaryDirectory
        let directory = baseURL.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var sampleStory: String {
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
        <Section id=\"intro\" title=\"Intro\">
        Hello.
        </Section>
        """
    }
}
