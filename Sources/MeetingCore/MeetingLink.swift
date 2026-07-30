import Foundation

/// Extracts supported conferencing links from calendar text.
public enum MeetingLink {
    private static let urlPattern = try! NSRegularExpression(
        pattern: #"https?://[^\s"'<>]+"#,
        options: .caseInsensitive
    )

    private static let trailingPunctuation: Set<Character> = [
        ".", ",", ";", "!", ")", "]", "}"
    ]

    /// Returns the first supported meeting URL in candidate order.
    ///
    /// Calendar URL fields are commonly generic web links. To preserve that
    /// useful behavior, an HTTP(S) fallback is returned only after all
    /// candidates have been searched for a recognized meeting provider.
    public static func extract(from candidates: [String], fallback: URL? = nil) -> URL? {
        for candidate in candidates {
            for url in urls(in: candidate) where provider(for: url) != nil {
                return url
            }
        }

        guard let fallback, isWebURL(fallback) else { return nil }
        return fallback
    }

    static func provider(for url: URL) -> MeetingProvider? {
        guard isWebURL(url), let host = url.host?.lowercased() else { return nil }

        if hostMatches(host, domain: "zoom.us"),
           url.path.hasPrefix("/j/"),
           url.path.dropFirst(3).isEmpty == false {
            return .zoom
        }
        if host == "meet.google.com", hasNonRootPath(url) {
            return .googleMeet
        }
        if (host == "teams.microsoft.com" || host == "teams.live.com"),
           hasNonRootPath(url) {
            return .teams
        }
        if hostMatches(host, domain: "webex.com"), hasNonRootPath(url) {
            return .webex
        }
        if hostMatches(host, domain: "whereby.com"), hasNonRootPath(url) {
            return .whereby
        }
        if hostMatches(host, domain: "around.co"), hasNonRootPath(url) {
            return .around
        }
        return nil
    }

    private static func urls(in text: String) -> [URL] {
        let range = NSRange(text.startIndex..., in: text)
        return urlPattern.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            var value = String(text[swiftRange])
            while let last = value.last, trailingPunctuation.contains(last) {
                value.removeLast()
            }
            return URL(string: value)
        }
    }

    private static func hostMatches(_ host: String, domain: String) -> Bool {
        host == domain || host.hasSuffix(".\(domain)")
    }

    private static func hasNonRootPath(_ url: URL) -> Bool {
        url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty == false
    }

    private static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

enum MeetingProvider: String {
    case zoom = "Zoom"
    case googleMeet = "Google Meet"
    case teams = "Teams"
    case webex = "Webex"
    case whereby = "Whereby"
    case around = "Around"
}
