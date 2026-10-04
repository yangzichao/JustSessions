import SwiftUI

/// A miniature of the main window, sized for a 112 by 72 point thumbnail: the sidebar with a selected Claude Code
/// session, and that session's terminal tab. It draws in its environment's theme and color scheme.
struct AppWindowSketch: View {
    /// Close, minimize, and zoom.
    private static let windowButtonColors: [UInt32] = [0xFF5F57, 0xFEBC2E, 0x28C840]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 38)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(ThemePalette.sidebarSurface)
            Rectangle()
                .fill(ThemePalette.hairline)
                .frame(width: 0.5)
            TerminalTabSketch()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ThemePalette.contentSurface)
        }
        // The divider is translucent; this keeps whatever lies under the sketch from showing through it.
        .background(ThemePalette.contentSurface)
        .accessibilityHidden(true)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2.5) {
                ForEach(Self.windowButtonColors, id: \.self) { hexValue in
                    Circle()
                        .fill(Color(nsColor: NSColor(hexValue: hexValue)))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.leading, 1)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(ThemePalette.raisedSurface)
                .overlay(RoundedRectangle(cornerRadius: 1.5, style: .continuous).strokeBorder(ThemePalette.hairline, lineWidth: 0.5))
                .frame(height: 5)
                .padding(.top, 6)

            SketchTextLine(width: 14, style: ThemePalette.ink.opacity(0.45))
                .padding(.leading, 1)
                .padding(.top, 6)
                .padding(.bottom, 2)
            sessionRow(provider: .codex, titleWidth: 15, isSelected: false)
            sessionRow(provider: .claude, titleWidth: 18, isSelected: true)
            sessionRow(provider: .antigravity, titleWidth: 12, isSelected: false)
        }
        .padding(.horizontal, 4)
        .padding(.top, 5)
    }

    /// Like `SidebarSessionRowLayout`: the CLI's dot and a title, washed in the CLI's hue with a bar when selected.
    private func sessionRow(provider: ConversationProvider, titleWidth: CGFloat, isSelected: Bool) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(provider.tintColor)
                .frame(width: 2.5, height: 2.5)
            SketchTextLine(width: titleWidth, style: ThemePalette.ink.opacity(isSelected ? 0.6 : 0.3))
            Spacer(minLength: 0)
        }
        .padding(.leading, 5)
        .frame(height: 7)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(provider.tintColor.opacity(0.16))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(provider.tintColor)
                            .frame(width: 1, height: 4)
                            .padding(.leading, 1)
                    }
            }
        }
    }
}
