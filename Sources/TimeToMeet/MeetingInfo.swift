import Foundation

struct MeetingInfo: Hashable, Identifiable {
    /// Unique per occurrence (shared meeting UID + start). Used for SwiftUI identity,
    /// dedup across calendars, and per-occurrence dismiss tracking.
    let id: String
    /// Stable across all occurrences of a series and across calendars holding the
    /// same meeting. Used for the user's alert on/off preference.
    let seriesID: String
    let title: String
    let startDate: Date
    let endDate: Date
    let joinURL: URL?
    let location: String?
}
