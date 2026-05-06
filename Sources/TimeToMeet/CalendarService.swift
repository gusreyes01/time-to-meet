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
        return events
            .filter { !$0.isAllDay }
            .filter { $0.endDate > now }
            .filter { ($0.status != .canceled) }
            .sorted { $0.startDate < $1.startDate }
            .map { e in
                let eid = e.eventIdentifier ?? UUID().uuidString
                return MeetingInfo(
                    id: "\(eid)-\(Int(e.startDate.timeIntervalSince1970))",
                    seriesID: eid,
                    title: e.title ?? "Untitled",
                    startDate: e.startDate,
                    endDate: e.endDate,
                    joinURL: MeetingLinkExtractor.extract(from: e),
                    location: e.location
                )
            }
    }
}
