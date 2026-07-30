import EventKit
import Foundation
import MeetingCore

enum MeetingLinkExtractor {
    static func extract(from event: EKEvent) -> URL? {
        let candidates: [String] = [
            event.url?.absoluteString,
            event.notes,
            event.location
        ].compactMap { $0 }

        return MeetingLink.extract(from: candidates, fallback: event.url)
    }
}
