import AppKit
import CoreGraphics
import Foundation

/// Detects whether the user is currently busy in a way that should suppress
/// the meeting alert overlay — primarily: screen sharing, or actively in a
/// video call.
enum CallDetector {
    /// Bundle IDs whose presence on-screen suggests an active call. We only
    /// suppress when one of these has a visible app-level window — running
    /// in the background doesn't count. Screen sharing through any of these
    /// apps is detected because the host app is by definition active during
    /// the share.
    private static let meetingBundleIDs: Set<String> = [
        "us.zoom.xos",                  // Zoom
        "us.zoom.ZoomClips",
        "com.microsoft.teams",          // Teams (legacy)
        "com.microsoft.teams2",         // Teams (new)
        "com.cisco.webexmeetingsapp",   // Webex
        "com.webex.meetingmanager",
        "com.apple.FaceTime",           // FaceTime
        "com.google.GoogleMeet",        // Google Meet desktop wrapper
        "com.tinyspeck.slackmacgap",    // Slack huddles
        "com.apple.ScreenSharing"       // macOS built-in screen sharing
    ]

    /// True if a known meeting/screen-share app has a normal (layer 0)
    /// on-screen window of reasonable size.
    static var isInActiveCall: Bool {
        let meetingPIDs: Set<Int> = Set(
            NSWorkspace.shared.runningApplications.compactMap { app in
                guard let id = app.bundleIdentifier,
                      meetingBundleIDs.contains(id) else { return nil }
                return Int(app.processIdentifier)
            }
        )
        guard !meetingPIDs.isEmpty else { return false }

        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        for win in info {
            guard let pid = win[kCGWindowOwnerPID as String] as? Int,
                  meetingPIDs.contains(pid) else { continue }
            let layer = win[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            if let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
               let w = bounds["Width"], let h = bounds["Height"],
               w > 200, h > 200 {
                return true
            }
        }
        return false
    }

    /// Combined gate used by AppState before showing the overlay.
    static var shouldSuppressAlert: Bool {
        isInActiveCall
    }
}
