import AppKit

struct TranscriptTextStyle: Equatable {
    var fontSize: CGFloat
    var isMonospaced = false
    var isSemibold = false
    var lineSpacing: CGFloat = 4
    var tone: TranscriptTextTone = .primary

    var font: NSFont {
        let weight: NSFont.Weight = isSemibold ? .semibold : .regular
        return isMonospaced ? .monospacedSystemFont(ofSize: fontSize, weight: weight) : .systemFont(ofSize: fontSize, weight: weight)
    }
}

enum TranscriptTextTone: Equatable {
    case primary
    case secondary
    case tertiary
}
