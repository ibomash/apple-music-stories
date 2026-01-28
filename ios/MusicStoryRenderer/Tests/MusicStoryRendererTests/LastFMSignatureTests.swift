@testable import MusicStoryRenderer
import XCTest

final class LastFMSignatureTests: XCTestCase {
    func testSignatureMatchesExpectedValue() {
        let parameters: [String: String] = [
            "api_key": "abc123",
            "artist": "Cher",
            "method": "track.scrobble",
            "sk": "session",
            "timestamp": "1600000000",
            "track": "Believe",
        ]
        let signature = LastFMAPISignature.sign(parameters: parameters, secret: "secret")
        XCTAssertEqual(signature, "f1f71a36ee4a5c7c4bf71ff9f9817c16")
    }
}
