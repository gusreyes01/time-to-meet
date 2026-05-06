import EventKit
import Foundation

enum MeetingLinkExtractor {
    private static let patterns: [String] = [
        #"https?://[a-z0-9.-]*zoom\.us/j/[^\s"'<>]+"#,
        #"https?://meet\.google\.com/[a-z0-9-]+"#,
        #"https?://teams\.microsoft\.com/[^\s"'<>]+"#,
        #"https?://[^\s"'<>]*webex\.com/[^\s"'<>]+"#,
        #"https?://[a-z0-9.-]+\.whereby\.com/[^\s"'<>]+"#,
        #"https?://[^\s"'<>]*around\.co/[^\s"'<>]+"#
    ]

    static func extract(from event: EKEvent) -> URL? {
        let candidates: [String] = [
            event.url?.absoluteString,
            event.notes,
            event.location
        ].compactMap { $0 }

        for text in candidates {
            for p in patterns {
                guard let regex = try? NSRegularExpression(pattern: p, options: .caseInsensitive) else { continue }
                let range = NSRange(text.startIndex..., in: text)
                if let m = regex.firstMatch(in: text, range: range),
                   let r = Range(m.range, in: text) {
                    return URL(string: String(text[r]))
                }
            }
        }

        if let url = event.url, url.scheme?.hasPrefix("http") == true {
            return url
        }
        return nil
    }
}
