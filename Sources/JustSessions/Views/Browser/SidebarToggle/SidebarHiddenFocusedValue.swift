import SwiftUI

private struct SidebarHiddenFocusedValueKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var isSidebarHidden: Binding<Bool>? {
        get { self[SidebarHiddenFocusedValueKey.self] }
        set { self[SidebarHiddenFocusedValueKey.self] = newValue }
    }
}
