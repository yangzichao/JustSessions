import CoreGraphics

/// How wide the conversation column may grow when reading a session: a readable column centered in the window,
/// or the full width of the window. The preview and every Read window share one choice.
///
/// The raw values are saved in settings, so they must stay the same for a saved choice to survive updates.
enum TranscriptReadingWidth: String, CaseIterable {
    case readable
    case full

    static let userDefaultsKey = "transcriptReadingWidth"

    /// The readable column keeps prose lines short enough to follow while leaving room for code and tables.
    static let readableColumnWidth: CGFloat = 760

    /// The widest the conversation column may be, before the reading padding on each side.
    var maximumColumnWidth: CGFloat {
        switch self {
        case .readable: Self.readableColumnWidth
        case .full: .infinity
        }
    }

    var displayName: String {
        switch self {
        case .readable: "Readable"
        case .full: "Full"
        }
    }

    /// The other width, which the reading toolbar switches to.
    var toggled: Self {
        switch self {
        case .readable: .full
        case .full: .readable
        }
    }
}
