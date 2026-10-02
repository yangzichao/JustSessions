import SwiftUI

/// The active window's sidebar visibility, so the View menu can toggle it even while a terminal has keyboard focus.
private struct SidebarHiddenFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var isSidebarHidden: Binding<Bool>? {
        get { self[SidebarHiddenFocusedValueKey.self] }
        set { self[SidebarHiddenFocusedValueKey.self] = newValue }
    }
}
