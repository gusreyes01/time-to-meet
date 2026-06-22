import SwiftUI

struct AlertOverlay: View {
    @EnvironmentObject var state: AppState
    @State private var pulse = false

    var body: some View {
        ZStack {
            Brand.backdrop.ignoresSafeArea()
            RadialGradient(
                colors: [Brand.indigo.opacity(0.35), .clear],
                center: .center, startRadius: 0, endRadius: 700
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
            let isNow = secs == 0
            let countdown = isNow ? "Now" : String(format: "%d:%02d", secs / 60, secs % 60)

            VStack(spacing: 26) {
                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                        Text(headerText(meetings).uppercased()).tracking(2)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.indigo)
                    .opacity(pulse ? 1.0 : 0.55)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)

                    VStack(spacing: 4) {
                        Text(countdown)
                            .font(.system(size: 96, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        if !isNow {
                            Text("MINUTES").tracking(4)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(meetings) { m in
                            MeetingCard(meeting: m) { state.joinAlerting(m) }
                        }
                    }
                    .frame(maxWidth: 560)
                }
                .padding(40)
                .background(Brand.panelRaised.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 44, y: 22)

                Button {
                    state.dismissAllAlerting()
                } label: {
                    Text(meetings.count == 1 ? "Dismiss" : "Dismiss all")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
        }
    }

    private func headerText(_ meetings: [MeetingInfo]) -> String {
        meetings.count == 1 ? "Starting now" : "\(meetings.count) meetings starting"
    }
}

private struct MeetingCard: View {
    let meeting: MeetingInfo
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 12)
            if meeting.joinURL != nil {
                Button(action: onJoin) {
                    Label("Join now", systemImage: "video.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Brand.onGreen)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Brand.green, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var subtitle: String {
        let f = DateFormatter()
        f.timeStyle = .short
        let time = f.string(from: meeting.startDate)
        if let platform = MeetingPlatform.name(for: meeting.joinURL) {
            return "\(time) · \(platform)"
        }
        return "Starts at \(time)"
    }
}
