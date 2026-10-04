import SwiftUI

struct TranscriptReadingToolbar: View {
    @Binding var fontSize: CGFloat
    @Binding var readingWidth: TranscriptReadingWidth
    let messageCount: Int
    let onFirstMessage: () -> Void
    let onLatestMessage: () -> Void
    var onFind: (() -> Void)?
    /// Set in the workspace preview only; a reading window has no button that opens another.
    var onOpenInNewWindow: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Text(messageCount == 1 ? "1 message" : "\(messageCount) messages")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if let onFind {
                Button("Find in conversation", systemImage: "magnifyingglass", action: onFind)
                    .labelStyle(.iconOnly)
                    .help("Find in conversation (⌘F)")
                    .accessibilityIdentifier("preview.find")
            }
            HStack(spacing: 12) {
                Button { fontSize = max(12, fontSize - 1) } label: { Text("A−") }
                    .disabled(fontSize <= 12)
                    .help("Smaller text")
                    .accessibilityLabel("Smaller reading text")
                Button { fontSize = min(22, fontSize + 1) } label: { Text("A+") }
                    .disabled(fontSize >= 22)
                    .help("Larger text")
                    .accessibilityLabel("Larger reading text")
            }
            .font(.system(size: 13, weight: .medium))
            readingWidthButton
            HStack(spacing: 12) {
                Button("First message", systemImage: "arrow.up.to.line", action: onFirstMessage)
                    .help("Go to the first available message")
                Button("Latest message", systemImage: "arrow.down.to.line", action: onLatestMessage)
                    .help("Go to the latest message")
            }
            .labelStyle(.iconOnly)
            if let onOpenInNewWindow {
                Button("Open in new window", systemImage: "macwindow.badge.plus", action: onOpenInNewWindow)
                    .labelStyle(.iconOnly)
                    .help("Open in a separate reading window")
                    .accessibilityIdentifier("preview.open-reading-window")
            }
        }
        .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 4, verticalPadding: 4))
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .accessibilityIdentifier("preview.reading-toolbar")
    }

    /// The icon shows what a click does: widen to the full window, or narrow back to the readable column.
    private var readingWidthButton: some View {
        Button("Reading width", systemImage: readingWidthSymbol) { readingWidth = readingWidth.toggled }
            .labelStyle(.iconOnly)
            .help(readingWidth == .readable ? "Use the full window width" : "Use a readable width")
            .accessibilityValue(readingWidth == .readable ? "Readable" : "Full")
            .accessibilityHint("Switches between a readable width and the full window width")
    }

    private var readingWidthSymbol: String {
        switch readingWidth {
        case .readable: "arrow.left.and.line.vertical.and.arrow.right"
        case .full: "arrow.right.and.line.vertical.and.arrow.left"
        }
    }
}
