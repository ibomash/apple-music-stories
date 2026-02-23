@testable import MusicStoryRenderer
import Foundation
import XCTest

final class StoryCatalogContextMenuBuilderTests: XCTestCase {
    func testBundledStoryIncludesCopyLinkAndCreatePlaylistOnly() {
        let item = makeItem(
            source: .bundled,
            sourceURL: URL(fileURLWithPath: "/tmp/bundled-story/story.mdx")
        )

        XCTAssertEqual(
            StoryCatalogContextMenuBuilder.actions(for: item),
            [.copyStoryLink, .createPlaylist]
        )
    }

    func testSavedAndRecentStoriesIncludeDeleteAction() {
        let remote = makeItem(
            source: .savedRemote,
            sourceURL: URL(string: "https://example.com/story.mdx")
        )
        let recentLocal = makeItem(
            source: .recentLocal,
            sourceURL: URL(fileURLWithPath: "/tmp/recent-story/story.mdx")
        )

        XCTAssertEqual(
            StoryCatalogContextMenuBuilder.actions(for: remote),
            [.copyStoryLink, .createPlaylist, .deleteStory]
        )
        XCTAssertEqual(
            StoryCatalogContextMenuBuilder.actions(for: recentLocal),
            [.copyStoryLink, .createPlaylist, .deleteStory]
        )
    }

    private func makeItem(source: StoryLaunchSource, sourceURL: URL?) -> StoryLaunchItem {
        let metadata = StoryMetadataSnapshot(document: StoryDocument.sample())
        return StoryLaunchItem(
            id: "\(source.rawValue)-\(metadata.id)",
            metadata: metadata,
            source: source,
            sourceURL: sourceURL,
            bookmarkData: nil,
            lastOpened: nil
        )
    }
}
