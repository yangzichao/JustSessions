import AppKit
import SwiftUI

struct TranscriptCodeBlock: View {
    let text: String
    let language: String?
    var segmentIndex = 0
    @Environment(\.transcriptReadingFontSize) private var fontSize
    @State private var hasCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.flatMap { $0.isEmpty ? nil : $0 } ?? "Code")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ThemePalette.secondaryText)
                Spacer()
                Button(hasCopied ? "Copied" : "Copy", systemImage: hasCopied ? "checkmark" : "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    hasCopied = NSPasteboard.general.setString(text, forType: .string)
                }
                .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 4, verticalPadding: 2))
                .font(.caption)
                .help("Copy code")
                .accessibilityLabel("Copy code")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            ThemeDivider()
            ScrollView(.horizontal) {
                TranscriptSearchableText(source: AttributedString(text), segmentIndex: segmentIndex, fontSize: fontSize - 1, isMonospaced: true, lineSpacing: 3)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(12)
            }
        }
        .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ThemePalette.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: text) { _, _ in hasCopied = false }
    }
}
