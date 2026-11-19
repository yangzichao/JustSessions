import SwiftUI

private struct WorkspaceNavigationFocusedValueKey: FocusedValueKey {
    typealias Value = WorkspaceNavigation
}

extension FocusedValues {
    var workspaceNavigation: WorkspaceNavigation? {
        get { self[WorkspaceNavigationFocusedValueKey.self] }
        set { self[WorkspaceNavigationFocusedValueKey.self] = newValue }
    }
}
