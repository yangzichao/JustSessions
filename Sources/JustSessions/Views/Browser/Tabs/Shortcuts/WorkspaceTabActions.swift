import SwiftUI

struct WorkspaceTabActions {
    let tabCount: Int
    let hasSelectedTab: Bool
    let isSplitShown: Bool
    let shownSplitOrientation: TerminalSplit.Orientation
    let canOpenSplitChooser: Bool
    let canReopenClosedTab: Bool
    let isEnabled: Bool
    let newSession: () -> Void
    let reopenClosedTab: () -> Void
    let closeSelectedTab: () -> Void
    let selectAdjacentTab: (_ movingForward: Bool) -> Void
    let selectTab: (_ shortcutNumber: Int) -> Void
    let openSplitChooser: () -> Void
    let separateShownSplit: () -> Void
    let closeShownSplitView: (_ side: TerminalSplit.Side) -> Void
    let reverseShownSplit: () -> Void
    let toggleShownSplitOrientation: () -> Void
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
