import EventKit
import Foundation

final class CalendarService {
    let store = EKEventStore()

    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { cont in
                store.requestAccess(to: .event) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
        }
    }

    func upcomingMeetings(within seconds: TimeInterval) async -> [MeetingInfo] {
        let calendars = store.calendars(for: .event).filter { cal in
            cal.type != .subscription &&
            cal.type != .birthday &&
            cal.allowsContentModifications
        }
        guard !calendars.isEmpty else { return [] }
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-60),
            end: now.addingTimeInterval(seconds),
            calendars: calendars
        )
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .filter { $0.endDate > now }
            .filter { $0.status != .canceled }
            .filter { isUserParticipating(in: $0) }
            .sorted { $0.startDate < $1.startDate }

        return deduplicated(events.map(makeMeetingInfo))
    }

    private func makeMeetingInfo(_ e: EKEvent) -> MeetingInfo {
        // The external (iCalendar UID) identifier is shared across calendars and
        // accounts for the same meeting, so it collapses copies that live on more
        // than one connected calendar. Fall back to the per-store event id.
        let seriesID = e.calendarItemExternalIdentifier ?? e.eventIdentifier ?? UUID().uuidString
        return MeetingInfo(
            id: "\(seriesID)-\(Int(e.startDate.timeIntervalSince1970))",
            seriesID: seriesID,
            title: e.title ?? "Untitled",
            startDate: e.startDate,
            endDate: e.endDate,
            joinURL: MeetingLinkExtractor.extract(from: e),
            location: e.location
        )
    }

    /// Collapses the same meeting appearing on multiple connected calendars into
    /// a single entry. Same UID + same start time is treated as one occurrence;
    /// when copies differ, we keep the one that carries a join link.
    private func deduplicated(_ meetings: [MeetingInfo]) -> [MeetingInfo] {
        var indexByID: [String: Int] = [:]
        var result: [MeetingInfo] = []
        for m in meetings {
            if let i = indexByID[m.id] {
                if result[i].joinURL == nil, m.joinURL != nil {
                    result[i] = m
                }
            } else {
                indexByID[m.id] = result.count
                result.append(m)
            }
        }
        return result
    }

    /// Whether the current user is actually a participant in this event, as
    /// opposed to merely being able to see it on a colleague's calendar that's
    /// been shared with them. Keeps events I organized, events I'm invited to
    /// (and haven't declined), and personal events with no invitee list.
    private func isUserParticipating(in event: EKEvent) -> Bool {
        if event.organizer?.isCurrentUser == true { return true }
        guard let attendees = event.attendees, !attendees.isEmpty else {
            // No invitee list — a personal/blocked-time event on a calendar I keep.
            return true
        }
        if let me = attendees.first(where: { $0.isCurrentUser }) {
            return me.participantStatus != .declined
        }
        // Has attendees, but I'm not one of them — a colleague's event leaking
        // in from a calendar they've shared with me.
        return false
    }
}
