import SwiftUI

struct AlertOverlay: View {
    @EnvironmentObject var state: AppState
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.10, blue: 0.20),
                    Color(red: 0.95, green: 0.40, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                content(at: ctx.date)
            }
        }
        .onAppear { pulse = true }
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        let meetings = state.alertingMeetings
        if meetings.isEmpty {
            EmptyView()
        } else {
            let soonest = meetings.min(by: { $0.startDate < $1.startDate }) ?? meetings[0]
            let secs = max(0, Int(soonest.startDate.timeIntervalSince(date)))
            let countdown = secs == 0 ? "Now" : String(format: "%d:%02d", secs / 60, secs % 60)

            VStack(spacing: 22) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)

                Text(headerText(meetings))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text(countdown)
                    .font(.system(size: 100, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                VStack(spacing: 12) {
                    ForEach(meetings) { m in
                        MeetingCard(meeting: m) { state.joinAlerting(m) }
                    }
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 60)

                Button {
                    state.dismissAllAlerting()
                } label: {
                    Text(meetings.count == 1 ? "Dismiss" : "Dismiss all")
                        .font(.system(size: 22, weight: .semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                )
                .foregroundStyle(.white)
            }
        }
    }

    private func headerText(_ meetings: [MeetingInfo]) -> String {
        meetings.count == 1 ? "Meeting starting" : "\(meetings.count) meetings starting"
    }
}

private struct MeetingCard: View {
    let meeting: MeetingInfo
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(timeText)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 12)
            if meeting.joinURL != nil {
                Button(action: onJoin) {
                    Label("Join", systemImage: "video.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Color.white)
                .foregroundStyle(Color(red: 0.85, green: 0.10, blue: 0.20))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private var timeText: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return "Starts at \(f.string(from: meeting.startDate))"
    }
}
