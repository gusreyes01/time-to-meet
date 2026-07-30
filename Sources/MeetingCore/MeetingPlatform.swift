import Foundation

/// Human-readable platform names for recognized meeting URLs.
public enum MeetingPlatform {
    public static func name(for url: URL?) -> String? {
        guard let url else { return nil }
        return MeetingLink.provider(for: url)?.rawValue
    }
}
