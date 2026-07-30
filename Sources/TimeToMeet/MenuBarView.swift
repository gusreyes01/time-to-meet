import MeetingCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var state: AppState
    var showsInlineSettings = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if showsInlineSettings {
                Divider().overlay(Color.white.opacity(0.08))
                settings
            }
            if !state.meetings.isEmpty {
                Divider().overlay(Color.white.opacity(0.08))
                attendingBanner
                upcomingList
            }
            Divider().overlay(Color.white.opacity(0.08))
            footer
        }
        .padding(14)
        .frame(width: 340)
        .background(Brand.panel)
        .environment(\.colorScheme, .dark)
        .tint(Brand.indigo)
    }

    private var brandMark: some View {
        Image(systemName: "play.circle.fill")
            .font(.system(size: 16))
            .foregroundStyle(Brand.indigo)
    }

    @ViewBuilder
    private var header: some View {
        switch state.calendarAccess {
        case .denied:
            VStack(alignment: .leading, spacing: 6) {
                Text("Calendar access needed").font(.headline)
                Text("Open System Settings → Privacy & Security → Calendars and enable Time to Meet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        case .unknown:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Connecting to your calendar…").font(.callout).foregroundStyle(.secondary)
            }
        case .granted:
            HStack(spacing: 8) {
                brandMark
                if let m = state.nextAlertableMeeting {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next alert").font(.caption).foregroundStyle(Brand.indigo)
                        Text(m.title).font(.headline).lineLimit(1)
                        Text(eventRowSubtitle(m)).font(.subheadline).foregroundStyle(.secondary)
                    }
                } else if state.nextMeeting != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No alerts queued").font(.headline)
                        Text("All upcoming meetings are unchecked.").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No upcoming meetings").font(.headline)
                        Text("You're clear for now.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable alerts", isOn: $state.enabled)
            HStack {
                Text("Alert lead time")
                Spacer()
                Stepper(value: $state.leadTimeMinutes, in: 1...30) {
                    Text("\(state.leadTimeMinutes) min").monospacedDigit()
                }
                .fixedSize()
            }
        }
    }

    private var attendingBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text("Showing only meetings you're attending")
        }
        .font(.caption)
        .foregroundStyle(Brand.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var upcomingList: some View {
        let total = state.meetings.count
        let limit = state.displayLimit
        let visible = Array(state.meetings.prefix(limit))
        let hasMore = total > limit

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Upcoming").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(visible.count) of \(total)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            ForEach(visible) { m in
                MeetingRow(meeting: m)
            }
            if hasMore {
                Button {
                    state.showMoreMeetings()
                } label: {
                    Label("Show 10 more", systemImage: "chevron.down").font(.caption)
                }
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Preview alert") { state.previewAlert() }
            Spacer()
            Button("Refresh") { Task { await state.refresh() } }
            Button("Quit") { state.quit() }
        }
        .controlSize(.small)
    }

    private func eventRowSubtitle(_ m: MeetingInfo) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        let start = f.string(from: m.startDate)
        let mins = Int(m.startDate.timeIntervalSince(state.now) / 60)
        if mins < 0 { return "\(start) · in progress" }
        if mins < 60 { return "\(start) · in \(mins) min" }
        return start
    }
}

private struct MeetingRow: View {
    let meeting: MeetingInfo
    @EnvironmentObject var state: AppState

    var body: some View {
        let selected = state.isSelected(meeting)
        let alertOn = Binding<Bool>(
            get: { state.isSelected(meeting) },
            set: { state.setSelected(meeting, $0) }
        )

        HStack(spacing: 10) {
            Button {
                alertOn.wrappedValue.toggle()
            } label: {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? Brand.indigo : Color.secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title)
                    .lineLimit(1)
                    .foregroundStyle(selected ? .primary : .secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(countdownLabel)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(countdownColor)
        }
        .font(.callout)
    }

    private var subtitle: String {
        let when = dateLabel(meeting.startDate)
        if let platform = MeetingPlatform.name(for: meeting.joinURL) {
            return "\(when) · \(platform)"
        }
        return when
    }

    private var minutesAway: Int { Int(meeting.startDate.timeIntervalSince(state.now) / 60) }

    private var countdownLabel: String {
        let mins = minutesAway
        if mins < 0 { return "now" }
        if mins == 0 { return "now" }
        if mins < 60 { return "\(mins) min" }
        return "\(mins / 60) hr"
    }

    private var countdownColor: Color {
        let mins = minutesAway
        if mins >= 0 && mins < 5 { return Color(red: 1.0, green: 0.42, blue: 0.5) }
        return .secondary
    }

    private func dateLabel(_ d: Date) -> String {
        let cal = Calendar.current
        let timeF = DateFormatter()
        timeF.timeStyle = .short
        let time = timeF.string(from: d)
        if cal.isDateInToday(d) { return time }
        if cal.isDateInTomorrow(d) { return "Tomorrow · \(time)" }
        let dayF = DateFormatter()
        dayF.dateFormat = "EEE"
        return "\(dayF.string(from: d)) · \(time)"
    }
}
