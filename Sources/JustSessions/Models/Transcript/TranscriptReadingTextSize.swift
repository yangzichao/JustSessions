import Foundation

enum TranscriptReadingTextSize {
    static let userDefaultsKey = "transcriptReadingTextSize"
    static let range = 12.0...22.0
    static let defaultSize = 15.0
    static let toolCallSummarySizeAtDefaultSize = 12.0
    static let noteSizeAtDefaultSize = 10.0

    static func toolCallSummarySize(forReadingSize readingSize: Double) -> Double {
        readingSize * toolCallSummarySizeAtDefaultSize / defaultSize
    }

    static func noteSize(forReadingSize readingSize: Double) -> Double {
        readingSize * noteSizeAtDefaultSize / defaultSize
    }

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
