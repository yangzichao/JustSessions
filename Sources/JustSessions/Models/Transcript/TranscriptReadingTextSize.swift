import Foundation

/// The size of a conversation's text, in points, set with A− and A+ in the reading toolbar or with View → Zoom In and
/// Zoom Out. The preview and every Read window share one size, remembered after quitting like the reading width.
///
/// The key is saved in settings, so it must stay the same for a saved size to survive updates.
enum TranscriptReadingTextSize {
    static let userDefaultsKey = "transcriptReadingTextSize"
    static let range = 12.0...22.0
    static let defaultSize = 15.0

    /// A saved size outside the range, which only a change outside the app can save, reads as the nearest one inside.
    static func clamped(_ size: Double) -> Double {
        size.isFinite ? min(max(size, range.lowerBound), range.upperBound) : defaultSize
    }

    static func size(after step: TextZoomStep, from size: Double) -> Double {
        step.size(after: clamped(size), in: range, defaultSize: defaultSize)
    }

    static func saved(in userDefaults: UserDefaults) -> Double {
        clamped(userDefaults.object(forKey: userDefaultsKey) as? Double ?? defaultSize)
    }

    static func zoom(_ step: TextZoomStep, in userDefaults: UserDefaults) {
        userDefaults.set(size(after: step, from: saved(in: userDefaults)), forKey: userDefaultsKey)
    }
}
