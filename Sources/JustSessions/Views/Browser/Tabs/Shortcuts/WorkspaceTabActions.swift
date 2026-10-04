import SwiftUI

/// Commands use the active window's actions even while its AppKit terminal has keyboard focus.
struct WorkspaceTabActions {
    let tabCount: Int
    let hasSelectedTab: Bool
    /// A split shows, so the Tabs menu's split view items act on it.
    let isSplitShown: Bool
    let isEnabled: Bool
    let newSession: () -> Void
    let closeSelectedTab: () -> Void
    let selectAdjacentTab: (_ movingForward: Bool) -> Void
    let selectTab: (_ shortcutNumber: Int) -> Void
    /// The shown split's actions, as Chrome's split view button offers them.
    let separateShownSplit: () -> Void
    let closeShownSplitView: (_ side: TerminalSplit.Side) -> Void
    let reverseShownSplit: () -> Void
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
