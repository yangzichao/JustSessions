import SwiftUI

/// One of the theme's colors, drawn in the theme and the light or dark appearance of the view that uses it. So a view
/// can show a theme other than the window's, as the thumbnails in Settings do.
struct ThemeColor: ShapeStyle {
    enum Role: Sendable {
        case sidebarSurface
        case contentSurface
        case raisedSurface
        case userMessageSurface
        case ink
        case inkForeground
        case secondaryText
        case line
        case tabGroup(Int)
        case terminalForeground
        /// One of the terminal's 16 ANSI colors, by its index.
        case terminalANSI(Int)
    }

    let role: Role
    var opacity: Double = 1

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let colors = environment.appTheme.colors(isDark: environment.colorScheme == .dark)
        let hexValue = switch role {
        case .sidebarSurface: colors.sidebarSurface
        case .contentSurface: colors.contentSurface
        case .raisedSurface: colors.raisedSurface
        case .userMessageSurface: colors.userMessageSurface
        case .ink: colors.ink
        case .inkForeground: colors.inkForeground
        case .secondaryText: colors.secondaryText
        case .line: colors.line
        case .tabGroup(let index): colors.tabGroupHexColors[index]
        case .terminalForeground: colors.terminal.foreground
        case .terminalANSI(let index): colors.terminal.ansiHexColors[index]
        }
        return Color(
            .sRGB,
            red: Double((hexValue >> 16) & 0xFF) / 255,
            green: Double((hexValue >> 8) & 0xFF) / 255,
            blue: Double(hexValue & 0xFF) / 255,
            opacity: opacity
        )
        .resolve(in: environment)
    }
}
