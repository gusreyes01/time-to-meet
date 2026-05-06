import AppKit
import EventKit
import Foundation
import SwiftUI

enum CalendarAccessState {
    case unknown, granted, denied
}

@MainActor
final class AppState: ObservableObject {
    @Published var meetings: [MeetingInfo] = []
    @Published var calendarAccess: CalendarAccessState = .unknown
    @Published private(set) var now: Date = Date()

    /// All meetings currently inside the alert lead window. The overlay shows them as one panel.
    @Published var alertingMeetings: [MeetingInfo] = []
    @Published private(set) var alertIsPreview: Bool = false
    var alertActive: Bool { !alertingMeetings.isEmpty }

    @Published var leadTimeMinutes: Int {
        didSet {
            UserDefaults.standard.set(leadTimeMinutes, forKey: Keys.leadTime)
            UserDefaults.standard.synchronize()
            evaluateAlert()
        }
    }
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Keys.enabled)
            UserDefaults.standard.synchronize()
            if !enabled { dismissAllAlerting() } else { evaluateAlert() }
        }
    }

    @Published private var skippedIDs: Set<String> = []
    @Published var displayLimit: Int = 10

    static let pageSize: Int = 10

    private let calendar = CalendarService()
    private var timer: Timer?
    private var overlayController = OverlayController()
    private var dismissedIDs: Set<String> = []
    private var lastRefresh: Date = .distantPast

    private enum Keys {
        static let leadTime = "leadTimeMinutes"
        static let enabled = "alertsEnabled"
        static let skippedIDs = "skippedMeetingIDs"
    }

    init() {
        let storedLead = UserDefaults.standard.object(forKey: Keys.leadTime) as? Int
        self.leadTimeMinutes = storedLead ?? 3
        let storedEnabled = UserDefaults.standard.object(forKey: Keys.enabled) as? Bool
        self.enabled = storedEnabled ?? true
        let storedSkipped = UserDefaults.standard.array(forKey: Keys.skippedIDs) as? [String] ?? []
        self.skippedIDs = Set(storedSkipped)

        Task { await requestAccessAndLoad() }
        startTimer()
    }

    var nextMeeting: MeetingInfo? {
        meetings.first { $0.startDate.timeIntervalSince(now) > -60 }
    }

    var nextAlertableMeeting: MeetingInfo? {
        meetings.first {
            $0.startDate.timeIntervalSince(now) > -60 && !skippedIDs.contains($0.seriesID)
        }
    }

    func isSkipped(_ meeting: MeetingInfo) -> Bool {
        skippedIDs.contains(meeting.seriesID)
    }

    func setSkipped(_ meeting: MeetingInfo, _ skip: Bool) {
        if skip {
            skippedIDs.insert(meeting.seriesID)
        } else {
            skippedIDs.remove(meeting.seriesID)
        }
        UserDefaults.standard.set(Array(skippedIDs), forKey: Keys.skippedIDs)
        UserDefaults.standard.synchronize()
        evaluateAlert()
    }

    func showMoreMeetings() {
        displayLimit += Self.pageSize
    }

    /// Short countdown shown in the menu bar when a meeting is within the lead window.
    var menuBarText: String? {
        guard enabled, let m = nextAlertableMeeting else { return nil }
        let secs = m.startDate.timeIntervalSince(now)
        // Show countdown in the menu bar starting 15 minutes before
        guard secs > -60, secs < 15 * 60 else { return nil }
        if secs <= 0 { return "now" }
        let mins = Int(secs) / 60
        let s = Int(secs) % 60
        return String(format: "%d:%02d", mins, s)
    }

    func requestAccessAndLoad() async {
        let granted = await calendar.requestAccess()
        calendarAccess = granted ? .granted : .denied
        if granted { await refresh() }
    }

    func refresh() async {
        meetings = await calendar.upcomingMeetings(within: 60 * 60 * 24 * 30)
        lastRefresh = Date()
        evaluateAlert()
    }

    func previewAlert() {
        let pid = "preview-\(UUID().uuidString)"
        let demo = MeetingInfo(
            id: pid,
            seriesID: pid,
            title: "Preview meeting",
            startDate: Date().addingTimeInterval(TimeInterval(leadTimeMinutes * 60)),
            endDate: Date().addingTimeInterval(TimeInterval(leadTimeMinutes * 60 + 1800)),
            joinURL: URL(string: "https://meet.google.com/preview"),
            location: nil
        )
        alertIsPreview = true
        alertingMeetings = [demo]
        overlayController.show(state: self)
    }

    func dismissAllAlerting() {
        if !alertIsPreview {
            for m in alertingMeetings {
                dismissedIDs.insert(m.id)
            }
        }
        alertIsPreview = false
        alertingMeetings = []
        overlayController.hide()
    }

    func joinAlerting(_ meeting: MeetingInfo) {
        if let url = meeting.joinURL {
            NSWorkspace.shared.open(url)
        }
        if !alertIsPreview {
            dismissedIDs.insert(meeting.id)
        }
        alertingMeetings.removeAll { $0.id == meeting.id }
        if alertingMeetings.isEmpty {
            alertIsPreview = false
            overlayController.hide()
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        now = Date()
        if Date().timeIntervalSince(lastRefresh) > 60 {
            Task { await refresh() }
        }
        evaluateAlert()
    }

    private func evaluateAlert() {
        if alertIsPreview { return }
        guard enabled else {
            if !alertingMeetings.isEmpty {
                alertingMeetings = []
                overlayController.hide()
            }
            return
        }

        let leadSecs = TimeInterval(leadTimeMinutes * 60)
        let inWindow = meetings.filter { m in
            let secs = m.startDate.timeIntervalSince(now)
            return secs <= leadSecs
                && secs > -60
                && !skippedIDs.contains(m.seriesID)
                && !dismissedIDs.contains(m.id)
        }

        if inWindow != alertingMeetings {
            alertingMeetings = inWindow
        }

        if inWindow.isEmpty {
            if overlayController.isShowing {
                overlayController.hide()
            }
        } else {
            overlayController.show(state: self)
        }
    }
}
