import XCTest

final class MusicStoryRendererUITests: XCTestCase {
    func testLaunchShowsStoryHeader() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Music Stories"].waitForExistence(timeout: 5))
    }
}
