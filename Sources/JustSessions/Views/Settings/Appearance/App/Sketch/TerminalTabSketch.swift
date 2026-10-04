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
            output
        }
    }

    /// Like `WorkspaceTabBar`: a strip in the sidebar's color, the selected tab in the terminal's color running down
    /// into the terminal, and another tab flat on the strip beside it.
    private var tabBar: some View {
        HStack(spacing: 5) {
            SketchTextLine(width: 14, style: ThemePalette.ink.opacity(0.8))
                .frame(width: 24, height: 10)
                .background {
                    WorkspaceTabShape(cornerRadius: 2.5, footRadius: 2)
                        .fill(ThemePalette.contentSurface)
                    WorkspaceTabShape(cornerRadius: 2.5, footRadius: 2, isOpenAtBottom: true)
                        .stroke(ThemePalette.hairline, lineWidth: 0.5)
                        .padding(.vertical, 0.25)
                }
            SketchTextLine(width: 12, style: ThemePalette.ink.opacity(0.3))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .padding(.top, 4)
        .background {
            ZStack(alignment: .bottom) {
                Rectangle().fill(ThemePalette.sidebarSurface)
                Rectangle().fill(ThemePalette.hairline).frame(height: 0.5)
            }
        }
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
