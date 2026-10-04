import SwiftUI

/// Starts the active workspace window's tour, so Help → Take the Tour works even while a terminal has keyboard focus.
/// Absent while that window shows a sheet, alert, or dialog.
private struct StartOnboardingTourFocusedValueKey: FocusedValueKey {
    typealias Value = StartOnboardingTourAction
}

extension FocusedValues {
    var startOnboardingTour: StartOnboardingTourAction? {
        get { self[StartOnboardingTourFocusedValueKey.self] }
        set { self[StartOnboardingTourFocusedValueKey.self] = newValue }
    }
}
