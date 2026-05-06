import Foundation

struct MeetingInfo: Hashable, Identifiable {
    /// Unique per occurrence (eventID + start). Used for SwiftUI identity and per-occurrence dismiss tracking.
    let id: String
    /// Stable across all occurrences of a recurring series. Used for the user's alert on/off preference.
    let seriesID: String
    let title: String
    let startDate: Date
    let endDate: Date
    let joinURL: URL?
    let location: String?
}
