import Foundation
import XCTest
@testable import MeetingCore

final class MeetingLinkTests: XCTestCase {
    func testExtractsSupportedLinksFromCalendarText() {
        let candidates = [
            "Join the design review at https://zoom.us/j/123456789.",
            "Backup: https://meet.google.com/abc-defg-hij"
        ]

        XCTAssertEqual(
            MeetingLink.extract(from: candidates)?.absoluteString,
            "https://zoom.us/j/123456789"
        )
    }

    func testPreservesCandidatePriority() {
        let candidates = [
            "https://meet.google.com/first-room",
            "https://zoom.us/j/999"
        ]

        XCTAssertEqual(
            MeetingLink.extract(from: candidates)?.host,
            "meet.google.com"
        )
    }

    func testRejectsLookalikeProviderHosts() {
        let candidates = [
            "https://evilzoom.us/j/123",
            "https://teams.microsoft.evil.example/meet/123",
            "https://webex.com.evil.example/meet/user"
        ]

        XCTAssertNil(MeetingLink.extract(from: candidates))
    }

    func testSupportsProviderSubdomainsAndRootDomains() {
        XCTAssertEqual(
            MeetingLink.extract(from: ["https://acme.zoom.us/j/456"])?.host,
            "acme.zoom.us"
        )
        XCTAssertEqual(
            MeetingLink.extract(from: ["https://whereby.com/product-team"])?.host,
            "whereby.com"
        )
        XCTAssertEqual(
            MeetingLink.extract(from: ["https://acme.webex.com/meet/alex"])?.host,
            "acme.webex.com"
        )
    }

    func testUsesWebFallbackOnlyAfterSearchingRecognizedLinks() {
        let fallback = URL(string: "https://example.com/event")!
        let candidates = [
            fallback.absoluteString,
            "Notes: https://around.co/r/team"
        ]

        XCTAssertEqual(
            MeetingLink.extract(from: candidates, fallback: fallback)?.host,
            "around.co"
        )
        XCTAssertEqual(
            MeetingLink.extract(from: ["no meeting here"], fallback: fallback),
            fallback
        )
    }

    func testRejectsNonWebFallbacksAndMissingMeetingPaths() {
        XCTAssertNil(
            MeetingLink.extract(
                from: ["plain text"],
                fallback: URL(string: "calshow://event/123")
            )
        )
        XCTAssertNil(MeetingLink.extract(from: ["https://zoom.us/j/"]))
        XCTAssertNil(MeetingLink.extract(from: ["https://meet.google.com/"]))
    }
}
