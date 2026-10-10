import SwiftUI

/// What the active workspace window shows: a tab's terminal, or the selected session's preview.
private struct TextZoomTargetKey: FocusedValueKey {
    typealias Value = TextZoomTarget
}

extension FocusedValues {
    var textZoomTarget: TextZoomTarget? {
        get { self[TextZoomTargetKey.self] }
        set { self[TextZoomTargetKey.self] = newValue }
    }
}
