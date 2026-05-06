import AppKit
import SwiftUI

@main
struct TimeToMeetApp: App {
    @StateObject private var state: AppState

    init() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.alluxi.timetomeet"
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID }
        if !others.isEmpty {
            exit(0)
        }
        _state = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(state)
        } label: {
            MenuBarLabel(state: state)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var state: AppState

    var body: some View {
        if let countdown = state.menuBarText {
            HStack(spacing: 4) {
                Image(systemName: "bell.fill")
                Text(countdown).monospacedDigit()
            }
        } else {
            Image(systemName: "calendar.badge.clock")
        }
    }
}
