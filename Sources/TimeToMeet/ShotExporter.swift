import AppKit
import SwiftUI

/// Renders the real UI views off-screen to PNGs (no screen-recording permission
/// needed). Launch with TTM_EXPORT=<dir> to produce store screenshot sources.
@MainActor
enum ShotExporter {
    static func exportIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["TTM_EXPORT"] else { return }
        let base = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let now = Date()
        func demo(_ title: String, _ mins: Int, _ url: String?) -> MeetingInfo {
            let start = now.addingTimeInterval(TimeInterval(mins * 60))
            return MeetingInfo(id: title, seriesID: title, title: title,
                               startDate: start, endDate: start.addingTimeInterval(1800),
                               joinURL: url.flatMap { URL(string: $0) }, location: nil)
        }

        let overlayState = AppState()
        overlayState.alertingMeetings = [demo("Design Sync", 2, "https://zoom.us/j/123")]
        render(AlertOverlay().environmentObject(overlayState),
               size: CGSize(width: 1512, height: 945), scale: 2,
               to: base.appendingPathComponent("overlay.png"))

        let menuState = AppState()
        menuState.calendarAccess = .granted
        let meetings = [
            demo("Design Sync", 3, "https://zoom.us/j/123"),
            demo("Engineering Standup", 17, "https://meet.google.com/abc-defg-hij"),
            demo("1:1 with Sam", 62, "https://teams.microsoft.com/l/meetup"),
            demo("Marketing Review", 150, "https://whereby.com/team"),
        ]
        menuState.meetings = meetings
        menuState.setSelected(meetings[0], true)
        menuState.setSelected(meetings[1], true)
        render(MenuBarView(showsInlineSettings: false).environmentObject(menuState),
               size: nil, scale: 2,
               to: base.appendingPathComponent("popover.png"))

        exit(0)
    }

    private static func render<V: View>(_ view: V, size: CGSize?, scale: CGFloat, to url: URL) {
        let content = AnyView(size.map { AnyView(view.frame(width: $0.width, height: $0.height)) } ?? AnyView(view))
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        guard let cg = renderer.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }
}
