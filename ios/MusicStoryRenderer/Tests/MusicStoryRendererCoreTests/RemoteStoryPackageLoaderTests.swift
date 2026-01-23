@testable import MusicStoryRendererCore
import XCTest

final class RemoteStoryPackageLoaderTests: XCTestCase {
    func testRejectsInvalidScheme() async {
        let loader = RemoteStoryPackageLoader(dataLoader: MockDataLoader { _ in throw TestError() })
        let url = URL(string: "ftp://example.com/story.mdx")!

        do {
            _ = try await loader.loadStory(from: url)
            XCTFail("Expected invalid scheme error")
        } catch {
            XCTAssertEqual(error as? RemoteStoryLoadError, .invalidScheme)
        }
    }

    func testRejectsInvalidExtension() async {
        let loader = RemoteStoryPackageLoader(dataLoader: MockDataLoader { _ in throw TestError() })
        let url = URL(string: "https://example.com/story.txt")!

        do {
            _ = try await loader.loadStory(from: url)
            XCTFail("Expected invalid extension error")
        } catch {
            XCTAssertEqual(error as? RemoteStoryLoadError, .invalidExtension)
        }
    }

    func testRejectsNonHttpResponse() async {
        let url = URL(string: "https://example.com/story.mdx")!
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        let loader = RemoteStoryPackageLoader(
            dataLoader: MockDataLoader { _ in (Data("ok".utf8), response) }
        )

        do {
            _ = try await loader.loadStory(from: url)
            XCTFail("Expected invalid response error")
        } catch {
            XCTAssertEqual(error as? RemoteStoryLoadError, .invalidResponse)
        }
    }

    func testRejectsInvalidStatusCode() async throws {
        let url = URL(string: "https://example.com/story.mdx")!
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil))
        let loader = RemoteStoryPackageLoader(
            dataLoader: MockDataLoader { _ in (Data("ok".utf8), response) }
        )

        do {
            _ = try await loader.loadStory(from: url)
            XCTFail("Expected invalid status code error")
        } catch {
            XCTAssertEqual(error as? RemoteStoryLoadError, .invalidStatusCode(404))
        }
    }

    func testRejectsEmptyResponse() async throws {
        let url = URL(string: "https://example.com/story.mdx")!
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        let loader = RemoteStoryPackageLoader(dataLoader: MockDataLoader { _ in (Data(), response) })

        do {
            _ = try await loader.loadStory(from: url)
            XCTFail("Expected empty response error")
        } catch {
            XCTAssertEqual(error as? RemoteStoryLoadError, .emptyResponse)
        }
    }

    func testRejectsUnreadableStory() async throws {
        let url = URL(string: "https://example.com/story.mdx")!
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        let loader = RemoteStoryPackageLoader(
            dataLoader: MockDataLoader { _ in (Data([0xD8]), response) }
        )

        do {
            _ = try await loader.loadStory(from: url)
            XCTFail("Expected unreadable story error")
        } catch {
            XCTAssertEqual(error as? RemoteStoryLoadError, .unreadableStory)
        }
    }

    func testLoadsValidStory() async throws {
        let url = URL(string: "https://example.com/stories/story.mdx")!
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        let storyText = makeStory(body: "<Section id=\"intro\" title=\"Intro\">Hello.</Section>")
        let loader = RemoteStoryPackageLoader(
            dataLoader: MockDataLoader { _ in (Data(storyText.utf8), response) }
        )

        let package = try await loader.loadStory(from: url)

        XCTAssertEqual(package.storyURL, url)
        XCTAssertEqual(package.assetBaseURL, url.deletingLastPathComponent())
        XCTAssertTrue(package.storyText.contains("schema_version"))
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

private struct MockDataLoader: HTTPDataLoading {
    let handler: @Sendable (URL) async throws -> (Data, URLResponse)

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await handler(url)
    }
}

private struct TestError: Error, Sendable {}
