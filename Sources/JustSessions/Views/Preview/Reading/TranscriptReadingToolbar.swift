import SwiftUI

struct TranscriptReadingToolbar: View {
    @Binding var fontSize: Double
    @Binding var readingWidth: TranscriptReadingWidth
    let messageCount: Int
    let onFirstMessage: () -> Void
    let onLatestMessage: () -> Void
    var onFind: (() -> Void)?
    var onOpenInNewWindow: (() -> Void)?
    var bookmarkMenu: TranscriptBookmarkMenu? = nil

    var body: some View {
        HStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                Text(messageCount == 1 ? "1 message" : "\(messageCount) messages")
                Text(messageCount, format: .number)
                Color.clear.frame(width: 0, height: 0)
            }
            .font(ThemeFont.caption)
            .foregroundStyle(ThemePalette.secondaryText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(messageCount == 1 ? "1 message" : "\(messageCount) messages"))
            if let onFind {
                Button("Find in conversation", systemImage: "magnifyingglass", action: onFind)
                    .labelStyle(.iconOnly)
                    .help("Find in conversation (⌘F)")
                    .accessibilityIdentifier("preview.find")
                    .onboardingTourStop(.findInConversation)
            }
            HStack(spacing: 12) {
                Button {
                    fontSize = TranscriptReadingTextSize.size(after: .zoomOut, from: fontSize)
                } label: {
                    Text("A−")
                }
                .disabled(fontSize <= TranscriptReadingTextSize.range.lowerBound)
                .help("Smaller text")
                .accessibilityLabel("Smaller reading text")
                Button {
                    fontSize = TranscriptReadingTextSize.size(after: .zoomIn, from: fontSize)
                } label: {
                    Text("A+")
                }
                .disabled(fontSize >= TranscriptReadingTextSize.range.upperBound)
                .help("Larger text")
                .accessibilityLabel("Larger reading text")
            }
            .font(ThemeFont.body.weight(.medium))
            readingWidthButton
            HStack(spacing: 12) {
                Button("First message", systemImage: "arrow.up.to.line", action: onFirstMessage)
                    .help("Go to the first available message")
                Button("Latest message", systemImage: "arrow.down.to.line", action: onLatestMessage)
                    .help("Go to the latest message")
                if let bookmarkMenu { bookmarkMenu }
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
