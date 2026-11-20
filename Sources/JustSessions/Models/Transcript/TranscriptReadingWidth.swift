import CoreGraphics

enum TranscriptReadingWidth: String, CaseIterable {
    case readable = "readable"
    case full = "full"

    static let userDefaultsKey = "transcriptReadingWidth"

    static let readableColumnWidth: CGFloat = 760

    var maximumColumnWidth: CGFloat {
        switch self {
        case .readable: Self.readableColumnWidth
        case .full: .infinity
        }
    }

    var toggled: Self {
        switch self {
        case .readable: .full
        case .full: .readable
        }
    }
}
