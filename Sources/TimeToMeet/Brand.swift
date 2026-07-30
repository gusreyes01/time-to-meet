import SwiftUI

/// Brand palette, sampled from the app icon and store artwork.
enum Brand {
    static let indigo = Color(red: 0.478, green: 0.341, blue: 0.973)   // #7A57F8
    static let blue = Color(red: 0.216, green: 0.412, blue: 0.898)     // #3769E5
    static let green = Color(red: 0.184, green: 0.820, blue: 0.541)    // #2FD18A

    static let panel = Color(red: 0.118, green: 0.102, blue: 0.196)    // dark glass surface
    static let panelRaised = Color(red: 0.153, green: 0.129, blue: 0.329) // #272154
    static let bgTop = Color(red: 0.157, green: 0.122, blue: 0.298)    // deep indigo
    static let bgBottom = Color(red: 0.043, green: 0.039, blue: 0.078) // near black
    static let onGreen = Color(red: 0.04, green: 0.05, blue: 0.10)     // dark text on green

    /// Primary brand gradient (icon ring / accents).
    static let gradient = LinearGradient(
        colors: [indigo, blue],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Full-screen alert backdrop.
    static let backdrop = LinearGradient(
        colors: [bgTop, bgBottom],
        startPoint: .top, endPoint: .bottom
    )
}
