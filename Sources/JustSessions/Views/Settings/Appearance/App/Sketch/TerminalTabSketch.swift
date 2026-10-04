import SwiftUI

/// The right side of `AppWindowSketch`: the tab bar with a session's terminal tab selected, and output in the theme's
/// terminal colors, where each theme looks most like itself.
struct TerminalTabSketch: View {
    /// Like the terminal preview in Settings: a title and a prompt, then green, yellow, and red lines, then blue, magenta,
    /// and cyan. Each bar is a width and an ANSI color index, or no index for plain text.
    private static let outputLines: [[(width: CGFloat, ansiIndex: Int?)]] = [
        [(22, nil)],
        [(3, nil), (18, nil)],
        [(12, 2), (16, nil)],
        [(16, 3), (24, nil)],
        [(11, 1), (22, nil)],
        [(9, 4), (12, 5), (9, 6)],
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabBar
            Rectangle()
                .fill(ThemePalette.hairline)
                .frame(height: 0.5)
            output
        }
    }

    /// Like `WorkspaceTabBar`: the selected tab raised on a chip with ink text, another tab flat beside it.
    private var tabBar: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ThemePalette.raisedSurface)
                .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(ThemePalette.hairline, lineWidth: 0.5))
                .overlay(SketchTextLine(width: 14, style: ThemePalette.ink.opacity(0.8)))
                .frame(width: 24, height: 8)
            SketchTextLine(width: 12, style: ThemePalette.ink.opacity(0.3))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .frame(height: 16)
    }

    private var output: some View {
        VStack(alignment: .leading, spacing: 3.5) {
            ForEach(Self.outputLines.indices, id: \.self) { lineIndex in
                HStack(spacing: 2.5) {
                    ForEach(Self.outputLines[lineIndex].indices, id: \.self) { barIndex in
                        let bar = Self.outputLines[lineIndex][barIndex]
                        if let ansiIndex = bar.ansiIndex {
                            SketchTextLine(width: bar.width, style: ThemeColor(role: .terminalANSI(ansiIndex)))
                        } else {
                            SketchTextLine(width: bar.width, style: ThemeColor(role: .terminalForeground, opacity: 0.55))
                        }
                    }
                }
            }
        }
        .padding(6)
    }
}
