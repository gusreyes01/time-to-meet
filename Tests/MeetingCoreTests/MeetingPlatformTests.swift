import Foundation
import XCTest
@testable import MeetingCore

final class MeetingPlatformTests: XCTestCase {
    func testNamesSupportedPlatforms() {
        let examples: [(String, String)] = [
            ("https://zoom.us/j/123", "Zoom"),
            ("https://meet.google.com/abc-defg-hij", "Google Meet"),
            ("https://teams.microsoft.com/l/meetup", "Teams"),
            ("https://teams.live.com/meet/123", "Teams"),
            ("https://company.webex.com/meet/user", "Webex"),
            ("https://whereby.com/team", "Whereby"),
            ("https://around.co/r/team", "Around")
        ]

        for (value, expected) in examples {
            XCTAssertEqual(
                MeetingPlatform.name(for: URL(string: value)),
                expected,
                value
            )
        }
    }

    func testReturnsNilForUnknownOrDeceptiveHosts() {
        XCTAssertNil(MeetingPlatform.name(for: URL(string: "https://example.com/meet")))
        XCTAssertNil(MeetingPlatform.name(for: URL(string: "https://zoom.us.evil.test/j/1")))
        XCTAssertNil(MeetingPlatform.name(for: nil))
    }
}
