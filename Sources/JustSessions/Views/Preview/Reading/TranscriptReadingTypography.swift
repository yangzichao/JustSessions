import SwiftUI

extension EnvironmentValues {
    @Entry var transcriptReadingFontSize: CGFloat = 15
}

enum TranscriptReadingTypography {
    static func inlineText(_ source: AttributedString, fontSize: CGFloat) -> AttributedString {
        var text = source
        for run in source.runs where run.inlinePresentationIntent?.contains(.code) == true {
            text[run.range].font = .system(size: fontSize - 1, design: .monospaced)
        }
        return text
    }
}
