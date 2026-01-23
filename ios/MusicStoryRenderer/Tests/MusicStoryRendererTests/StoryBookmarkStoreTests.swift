@testable import MusicStoryRenderer
import XCTest

final class StoryBookmarkStoreTests: XCTestCase {
    private let suiteName = "StoryBookmarkStoreTests"

    func testSaveAndLoadAnchorID() {
        let defaults = makeDefaults()
        let store = StoryBookmarkStore(defaults: defaults)

        store.saveAnchorID("section-2", for: "story-1")

        let anchorID = store.loadAnchorID(for: "story-1")
        XCTAssertEqual(anchorID, "section-2")
    }

    func testClearAnchorIDRemovesValue() {
        let defaults = makeDefaults()
        let store = StoryBookmarkStore(defaults: defaults)

        store.saveAnchorID("block-7", for: "story-2")
        store.clearAnchorID(for: "story-2")

        XCTAssertNil(store.loadAnchorID(for: "story-2"))
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
