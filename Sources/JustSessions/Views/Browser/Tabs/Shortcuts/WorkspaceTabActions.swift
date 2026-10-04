import SwiftUI

/// Commands use the active window's actions even while its AppKit terminal has keyboard focus.
struct WorkspaceTabActions {
    let tabCount: Int
    let hasSelectedTab: Bool
    /// Two tabs show side by side, so the split's sides can trade or the split can end.
    let isSplitShown: Bool
    let isEnabled: Bool
    let newSession: () -> Void
    let closeSelectedTab: () -> Void
    let selectAdjacentTab: (_ movingForward: Bool) -> Void
    let selectTab: (_ shortcutNumber: Int) -> Void
    let swapSplitSides: () -> Void
    let leaveSplitView: () -> Void
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
