import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            settings
            if !state.meetings.isEmpty {
                Divider()
                upcomingList
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
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
            if let m = state.nextAlertableMeeting {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next alert").font(.caption).foregroundStyle(.secondary)
                    Text(m.title).font(.headline).lineLimit(2)
                    Text(eventRowSubtitle(m))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if state.nextMeeting != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No alerts queued").font(.headline)
                    Text("All upcoming meetings are unchecked.").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No upcoming meetings").font(.headline)
                    Text("You're clear for now.").font(.caption).foregroundStyle(.secondary)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ForEach(visible) { m in
                MeetingRow(meeting: m)
            }
            if hasMore {
                Button {
                    state.showMoreMeetings()
                } label: {
                    Label("Show 10 more", systemImage: "chevron.down")
                        .font(.caption)
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

    private func timeOnly(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: d)
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

        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title)
                    .lineLimit(1)
                    .foregroundStyle(selected ? .primary : .secondary)
                Text(dateLabel(meeting.startDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Toggle("", isOn: alertOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
        }
        .font(.callout)
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
