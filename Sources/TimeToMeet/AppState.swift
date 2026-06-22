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

    /// Set of meeting series IDs the user has explicitly opted in for alerts.
    /// Default behavior: meetings start unchecked (no alert) until the user
    /// ticks the box in the menu bar list.
    @Published private var selectedSeriesIDs: Set<String> = []
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
        static let selectedSeriesIDs = "selectedMeetingSeries"
    }

    init() {
        let storedLead = UserDefaults.standard.object(forKey: Keys.leadTime) as? Int
        self.leadTimeMinutes = storedLead ?? 3
        let storedEnabled = UserDefaults.standard.object(forKey: Keys.enabled) as? Bool
        self.enabled = storedEnabled ?? true
        let storedSelected = UserDefaults.standard.array(forKey: Keys.selectedSeriesIDs) as? [String] ?? []
        self.selectedSeriesIDs = Set(storedSelected)

        // In export mode we only need to render views from injected state — skip
        // calendar access and the timer so no TCC prompt or ticking interferes.
        if ProcessInfo.processInfo.environment["TTM_EXPORT"] != nil { return }

        Task { await requestAccessAndLoad() }
        startTimer()

        // Screenshot/QA affordance: launch with TTM_PREVIEW=overlay to auto-show
        // the preview alert (used for capturing store screenshots).
        if ProcessInfo.processInfo.environment["TTM_PREVIEW"] == "overlay" {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                self.previewAlert()
            }
        }
    }

    var nextMeeting: MeetingInfo? {
        meetings.first { $0.startDate.timeIntervalSince(now) > -60 }
    }

    var nextAlertableMeeting: MeetingInfo? {
        meetings.first {
            $0.startDate.timeIntervalSince(now) > -60 && selectedSeriesIDs.contains($0.seriesID)
        }
    }

    func isSelected(_ meeting: MeetingInfo) -> Bool {
        selectedSeriesIDs.contains(meeting.seriesID)
    }

    func setSelected(_ meeting: MeetingInfo, _ selected: Bool) {
        if selected {
            selectedSeriesIDs.insert(meeting.seriesID)
        } else {
            selectedSeriesIDs.remove(meeting.seriesID)
        }
        UserDefaults.standard.set(Array(selectedSeriesIDs), forKey: Keys.selectedSeriesIDs)
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

        // Don't pop the overlay while the mic or camera is live — the user is on
        // a call and the overlay would interrupt them or be visible to viewers.
        // If an overlay was already showing when the call started, hide it.
        if CallDetector.shouldSuppressAlert {
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
                && selectedSeriesIDs.contains(m.seriesID)
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
