import SwiftUI

private struct StartOnboardingTourFocusedValueKey: FocusedValueKey {
    typealias Value = StartOnboardingTourAction
}

extension FocusedValues {
    var startOnboardingTour: StartOnboardingTourAction? {
        get { self[StartOnboardingTourFocusedValueKey.self] }
        set { self[StartOnboardingTourFocusedValueKey.self] = newValue }
    }
}
