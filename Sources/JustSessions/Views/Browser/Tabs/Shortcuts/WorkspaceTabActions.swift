import SwiftUI

/// Commands use the active window's actions even while its AppKit terminal has keyboard focus.
struct WorkspaceTabActions {
    let tabCount: Int
    let hasSelectedTab: Bool
    let isEnabled: Bool
    let canSplitSelectedTab: Bool
    let canClosePane: Bool
    let newSession: () -> Void
    let closeSelectedTab: () -> Void
    let selectAdjacentTab: (_ movingForward: Bool) -> Void
    let selectTab: (_ shortcutNumber: Int) -> Void
    /// Docks the selected tab beside (`false`) or below (`true`) the focused pane.
    let splitSelectedTab: (_ downward: Bool) -> Void
    let closeFocusedPane: () -> Void
}

private struct WorkspaceTabActionsKey: FocusedValueKey {
    typealias Value = WorkspaceTabActions
}

extension FocusedValues {
    var workspaceTabActions: WorkspaceTabActions? {
        get { self[WorkspaceTabActionsKey.self] }
        set { self[WorkspaceTabActionsKey.self] = newValue }
    }
}
