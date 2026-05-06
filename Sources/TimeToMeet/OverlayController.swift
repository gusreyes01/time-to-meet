import AppKit
import SwiftUI

@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []

    var isShowing: Bool { !windows.isEmpty }

    func show(state: AppState) {
        if !windows.isEmpty { return }

        for screen in NSScreen.screens {
            let view = AlertOverlay().environmentObject(state)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.contentViewController = hosting
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        for w in windows {
            w.orderOut(nil)
            w.close()
        }
        windows.removeAll()
    }
}
