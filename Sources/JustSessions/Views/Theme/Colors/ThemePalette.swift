import AppKit
import SwiftUI

enum ThemePalette {
    static let sidebarSurface = ThemeColor(role: .sidebarSurface)
    static let contentSurface = ThemeColor(role: .contentSurface)
    static let raisedSurface = ThemeColor(role: .raisedSurface)
    static let userMessageSurface = ThemeColor(role: .userMessageSurface)

    static let ink = ThemeColor(role: .ink)
    static let inkForeground = ThemeColor(role: .inkForeground)
    /// Supporting copy, using the chosen theme's ink with sufficient contrast on its surfaces. Use it in place of the
    /// system's `.secondary`, which is 3.0 on light surfaces.
    static let secondaryText = ThemeColor(role: .secondaryText)
    /// The faintest copy, such as timestamps and counts, still readable. Use it in place of the system's `.tertiary`,
    /// which is 1.7 on light surfaces.
    static let tertiaryText = ThemeColor(role: .tertiaryText)
    static let hoverFill = ThemeColor(role: .line, opacity: ThemeFillOpacity.hover)
    static let pressedFill = ThemeColor(role: .line, opacity: ThemeFillOpacity.pressed)
    static let trackFill = ThemeColor(role: .line, opacity: ThemeFillOpacity.track)
    static let hairline = ThemeColor(role: .line, opacity: ThemeFillOpacity.hairline)

    static let live = Color.adaptive(StatusHexColors.live)
    static let liveNSColor = NSColor.adaptive(
        light: NSColor(hexValue: StatusHexColors.live.light), dark: NSColor(hexValue: StatusHexColors.live.dark))
    static let warning = Color.adaptive(StatusHexColors.warning)
    static let unseenTurn = Color.adaptive(StatusHexColors.unseenTurn)
    static let warningText = ThemeColor(role: .warningText)
    static let errorText = ThemeColor(role: .errorText)
}
