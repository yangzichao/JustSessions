import SwiftUI

struct TranscriptReadingToolbar: View {
    @Binding var fontSize: CGFloat
    let messageCount: Int
    let onFirstMessage: () -> Void
    let onLatestMessage: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(messageCount == 1 ? "1 message" : "\(messageCount) messages")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
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
            HStack(spacing: 12) {
                Button("First message", systemImage: "arrow.up.to.line", action: onFirstMessage)
                    .help("Go to the first available message")
                Button("Latest message", systemImage: "arrow.down.to.line", action: onLatestMessage)
                    .help("Go to the latest message")
            }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .accessibilityIdentifier("preview.reading-toolbar")
    }
}
