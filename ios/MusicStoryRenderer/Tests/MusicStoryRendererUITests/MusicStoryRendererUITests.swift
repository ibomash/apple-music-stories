import XCTest

final class MusicStoryRendererUITests: XCTestCase {
    func testLaunchShowsStoryHeader() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Music Stories"].waitForExistence(timeout: 5))
    }

    func testNowPlayingSheetOpensFromPlaybackBar() {
        let app = XCUIApplication()
        app.launch()

        let openStoryButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Open Story")
        ).firstMatch
        XCTAssertTrue(openStoryButton.waitForExistence(timeout: 5))
        openStoryButton.tap()

        let playButton = app.buttons["Play"].firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
        playButton.tap()

        let playbackBar = app.otherElements["playback-bar"]
        XCTAssertTrue(playbackBar.waitForExistence(timeout: 5))
        playbackBar.tap()

        XCTAssertTrue(app.navigationBars["Now Playing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testLastFMSettingsAccessible() {
        let app = XCUIApplication()
        app.launch()

        let settingsButton = app.buttons["lastfm-settings-link"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Last.fm"].waitForExistence(timeout: 5))
    }
}
