import SwiftUI

/// A miniature of the main window in the theme's colors, sized for a 112 by 72 point thumbnail: the sidebar with a
/// selected Claude Code session, and that session's preview. It draws in its environment's color scheme.
struct AppWindowSketch: View {
    private static let selectedProvider = ConversationProvider.claude
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
            preview
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

            textLine(width: 14, opacity: 0.45)
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
            textLine(width: titleWidth, opacity: isSelected ? 0.6 : 0.3)
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

    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            previewHeader
            Rectangle()
                .fill(ThemePalette.hairline)
                .frame(height: 0.5)
            transcript
        }
    }

    /// Like `SessionPreviewHeader`: the CLI's badge, title and details, and the Resume button in the CLI's hue.
    private var previewHeader: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Self.selectedProvider.tintColor.opacity(0.18))
                .overlay(Circle().fill(Self.selectedProvider.tintColor).frame(width: 2.5, height: 2.5))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                textLine(width: 20, height: 2.5, opacity: 0.75)
                textLine(width: 14, height: 1.5, opacity: 0.3)
            }
            Spacer(minLength: 2)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Self.selectedProvider.emphasisTintColor)
                .frame(width: 13, height: 5.5)
        }
        .padding(.horizontal, 5)
        .frame(height: 18)
    }

    /// Like `TranscriptEntryView`: your message on its own surface, then the reply under the CLI's name.
    private var transcript: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(ThemePalette.userMessageSurface)
                .overlay(alignment: .leading) {
                    textLine(width: 28, height: 1.5, opacity: 0.4)
                        .padding(.leading, 4)
                }
                .frame(height: 9)
            Capsule()
                .fill(Self.selectedProvider.tintColor)
                .frame(width: 10, height: 1.5)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                textLine(width: 52, height: 1.5, opacity: 0.25)
                textLine(width: 46, height: 1.5, opacity: 0.25)
                textLine(width: 34, height: 1.5, opacity: 0.25)
            }
            .padding(.top, 3)
        }
        .padding(6)
    }

    /// A line of text, drawn as a bar of ink.
    private func textLine(width: CGFloat, height: CGFloat = 2, opacity: Double) -> some View {
        Capsule()
            .fill(ThemePalette.ink.opacity(opacity))
            .frame(width: width, height: height)
    }
}
