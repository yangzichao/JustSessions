import AppKit
import SwiftUI

struct ThemeColor: ShapeStyle {
    enum Role: Sendable {
        case sidebarSurface
        case contentSurface
        case raisedSurface
        case userMessageSurface
        case ink
        case inkForeground
        case secondaryText
        case tertiaryText
        case warningText
        case errorText
        case providerText(ConversationProvider)
        case line
        case selectedRow(ConversationProvider?)
        case tabGroup(Int)
        case terminalForeground
        case terminalANSI(Int)
    }

    let role: Role
    var opacity: Double = 1

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let hexValue = hexValue(in: environment.appTheme.colors(isDark: environment.colorScheme == .dark))
        return Color(
            .sRGB,
            red: Double((hexValue >> 16) & 0xFF) / 255,
            green: Double((hexValue >> 8) & 0xFF) / 255,
            blue: Double(hexValue & 0xFF) / 255,
            opacity: opacity
        )
        .resolve(in: environment)
    }

    func nsColor(in theme: ResolvedAppTheme, isDark: Bool) -> NSColor {
        let hexValue = hexValue(in: theme.colors(isDark: isDark))
        return NSColor(
            srgbRed: CGFloat((hexValue >> 16) & 0xFF) / 255,
            green: CGFloat((hexValue >> 8) & 0xFF) / 255,
            blue: CGFloat(hexValue & 0xFF) / 255,
            alpha: opacity
        )
    }

    private func hexValue(in colors: AppThemeColors) -> UInt32 {
        switch role {
        case .sidebarSurface: colors.sidebarSurface
        case .contentSurface: colors.contentSurface
        case .raisedSurface: colors.raisedSurface
        case .userMessageSurface: colors.userMessageSurface
        case .ink: colors.ink
        case .inkForeground: colors.inkForeground
        case .secondaryText: colors.secondaryText
        case .tertiaryText: colors.tertiaryText
        case .warningText: colors.warningText
        case .errorText: colors.errorText
        case .providerText(let provider): colors.providerTextHexColors[provider, default: colors.ink]
        case .line: colors.line
        case .selectedRow(let provider): colors.selectedRowSurfaces[provider, default: colors.sidebarSurface]
        case .tabGroup(let index): colors.tabGroupHexColors[index]
        case .terminalForeground: colors.terminal.foreground
        case .terminalANSI(let index): colors.terminal.ansiHexColors[index]
        }
    }
}
