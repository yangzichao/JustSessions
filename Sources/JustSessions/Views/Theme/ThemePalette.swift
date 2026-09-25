import AppKit
import SwiftUI

/// The app's colors. Surfaces are warm neutrals instead of system gray and white, the chrome uses the brand Ink,
/// and saturated color is kept for meaning: each CLI's brand hue and the green of a running CLI.
enum ThemePalette {
    // MARK: Surfaces

    /// Behind the sidebar: a warm stone that sets the list apart from the reading surface.
    static let sidebarSurface = Color.adaptive(light: 0xF3F1EC, dark: 0x19191C)
    /// Behind the preview, the tab bar, and terminals: warm paper rather than pure white or black.
    static let contentSurface = Color(nsColor: contentSurfaceNSColor)
    static let contentSurfaceNSColor = NSColor.adaptive(light: NSColor(hexValue: 0xFCFBF8), dark: NSColor(hexValue: 0x1F1F23))
    /// Raised controls on a surface: the search field, the selected segment, the selected tab.
    static let raisedSurface = Color.adaptive(light: 0xFFFFFF, dark: 0x2C2C31)
    /// Your messages in a transcript.
    static let userMessageSurface = Color.adaptive(light: 0xF1EDE6, dark: 0x2A2A2F)

    // MARK: Ink

    /// The brand Ink, used where other apps put the system accent: the new-session badge and the selected tab text.
    static let ink = Color.adaptive(light: 0x15171C, dark: 0xECEAE5)
    /// Text and glyphs drawn on top of `ink`.
    static let inkForeground = Color.adaptive(light: 0xFFFFFF, dark: 0x15171C)
    /// Faint ink fills: the pointer over a row, a track behind a segmented control.
    static let hoverFill = Color.adaptive(light: 0x15171C, dark: 0xFFFFFF).opacity(0.055)
    static let trackFill = Color.adaptive(light: 0x15171C, dark: 0xFFFFFF).opacity(0.06)
    /// Hairlines between regions and around raised controls.
    static let hairline = Color.adaptive(light: 0x15171C, dark: 0xFFFFFF).opacity(0.09)

    // MARK: Status

    /// A running CLI.
    static let live = Color.adaptive(light: 0x1FA463, dark: 0x3DD68C)
    /// A warning that needs attention, such as an unreachable remote host.
    static let warning = Color.adaptive(light: 0xE0892B, dark: 0xF2A54A)
}
