import Foundation

/// What one workspace pane shows.
enum WorkspacePaneContent: Hashable, Codable, Sendable {
    /// The pane that behaves like the whole detail area does without splits: the selected tab's terminal, or the
    /// selected session's preview. Every layout has exactly one, so an unsplit workspace is unchanged.
    case selection
    /// A terminal tab docked to its own pane, by `TerminalSession` id.
    case terminal(UUID)
    /// A read-only session preview, by `Conversation` id.
    case preview(String)
}

/// The side of a pane that a tab is docked to. Docking on `leading`/`trailing` puts the new pane beside it;
/// `top`/`bottom` stacks them.
enum WorkspacePaneEdge: CaseIterable, Sendable {
    case leading
    case trailing
    case top
    case bottom

    var isHorizontal: Bool { self == .leading || self == .trailing }
    /// Whether the docked pane comes before the pane it was dropped on.
    var insertsBefore: Bool { self == .leading || self == .top }
}

/// Two panes or subtrees side by side or stacked, divided at `fraction` of the split's length.
struct WorkspacePaneSplit: Equatable, Codable, Sendable {
    /// The range dividers may move in, so no pane vanishes or starves its neighbor.
    static let fractionRange = 0.1...0.9

    var isHorizontal: Bool
    var fraction: Double {
        didSet { fraction = Self.fractionRange.clamped(fraction) }
    }
    var leading: WorkspacePaneLayout
    var trailing: WorkspacePaneLayout

    init(isHorizontal: Bool, fraction: Double = 0.5, leading: WorkspacePaneLayout, trailing: WorkspacePaneLayout) {
        self.isHorizontal = isHorizontal
        self.fraction = Self.fractionRange.clamped(fraction)
        self.leading = leading
        self.trailing = trailing
    }
}

/// The workspace's tiling: a tree whose leaves are panes. Operations return a new layout and keep two rules: the
/// `.selection` pane always exists exactly once, and a tab or preview appears in at most one pane.
indirect enum WorkspacePaneLayout: Equatable, Codable, Sendable {
    case pane(WorkspacePaneContent)
    case split(WorkspacePaneSplit)

    /// Today's unsplit workspace.
    static let selectionOnly = WorkspacePaneLayout.pane(.selection)

    var isSelectionOnly: Bool { self == .selectionOnly }

    /// Every pane, leading-to-trailing and top-to-bottom.
    var panes: [WorkspacePaneContent] {
        switch self {
        case .pane(let content): [content]
        case .split(let split): split.leading.panes + split.trailing.panes
        }
    }

    func contains(_ content: WorkspacePaneContent) -> Bool {
        panes.contains(content)
    }

    /// Splits the pane holding `target`, putting `content` on its `edge`. Content already in another pane moves:
    /// its old pane closes first. Docking the selection, onto a missing target, or onto itself changes nothing.
    func docking(_ content: WorkspacePaneContent, on edge: WorkspacePaneEdge, of target: WorkspacePaneContent) -> WorkspacePaneLayout {
        guard content != .selection, content != target, contains(target) else { return self }
        let withoutContent = closing(content)
        // Closing the content's old pane may have collapsed the split the target was in, never the target itself.
        return withoutContent.splitting(target, inserting: content, on: edge)
    }

    /// Moves `content` into the pane holding `target`, swapping what that pane showed into the moved content's old
    /// pane when it had one. Moving onto the selection pane or a missing target changes nothing: the selection pane
    /// already shows whichever tab is selected.
    func movingToCenter(_ content: WorkspacePaneContent, of target: WorkspacePaneContent) -> WorkspacePaneLayout {
        guard content != .selection, target != .selection, content != target, contains(target) else { return self }
        if contains(content) {
            return mappingPanes { $0 == content ? target : $0 == target ? content : $0 }
        }
        return mappingPanes { $0 == target ? content : $0 }
    }

    /// Removes the pane holding `content`; its sibling takes the whole split. The selection pane never closes.
    func closing(_ content: WorkspacePaneContent) -> WorkspacePaneLayout {
        guard content != .selection else { return self }
        switch self {
        case .pane:
            return self
        case .split(let split):
            if split.leading == .pane(content) { return split.trailing }
            if split.trailing == .pane(content) { return split.leading }
            var updated = split
            updated.leading = split.leading.closing(content)
            updated.trailing = split.trailing.closing(content)
            return .split(updated)
        }
    }

    /// Panes for terminals that no longer exist close, as when a tab's CLI ends while docked.
    func closingTerminals(notIn terminalIDs: Set<UUID>) -> WorkspacePaneLayout {
        panes.reduce(self) { layout, content in
            if case .terminal(let id) = content, !terminalIDs.contains(id) { return layout.closing(content) }
            return layout
        }
    }

    /// Panes previewing sessions that no longer exist close, as when a previewed session is deleted.
    func closingPreviews(notIn conversationIDs: Set<String>) -> WorkspacePaneLayout {
        panes.reduce(self) { layout, content in
            if case .preview(let id) = content, !conversationIDs.contains(id) { return layout.closing(content) }
            return layout
        }
    }

    /// Where focus goes when the pane holding `content` closes: its sibling's first pane, or the selection pane.
    func focusTarget(afterClosing content: WorkspacePaneContent) -> WorkspacePaneContent {
        sibling(of: content)?.panes.first ?? .selection
    }

    private func sibling(of content: WorkspacePaneContent) -> WorkspacePaneLayout? {
        guard case .split(let split) = self else { return nil }
        if split.leading == .pane(content) { return split.trailing }
        if split.trailing == .pane(content) { return split.leading }
        return split.leading.sibling(of: content) ?? split.trailing.sibling(of: content)
    }

    private func splitting(
        _ target: WorkspacePaneContent,
        inserting content: WorkspacePaneContent,
        on edge: WorkspacePaneEdge
    ) -> WorkspacePaneLayout {
        switch self {
        case .pane(target):
            let inserted = WorkspacePaneLayout.pane(content)
            return .split(WorkspacePaneSplit(
                isHorizontal: edge.isHorizontal,
                leading: edge.insertsBefore ? inserted : self,
                trailing: edge.insertsBefore ? self : inserted
            ))
        case .pane:
            return self
        case .split(let split):
            var updated = split
            updated.leading = split.leading.splitting(target, inserting: content, on: edge)
            updated.trailing = split.trailing.splitting(target, inserting: content, on: edge)
            return .split(updated)
        }
    }

    /// Sets one split's divider position. Splits are numbered in order: a split's leading subtree first, then
    /// the split itself, then its trailing subtree — the order `WorkspacePaneGeometry` hands out divider indices.
    func settingFraction(_ fraction: Double, atSplitIndex index: Int) -> WorkspacePaneLayout {
        var counter = 0
        return visitingSplits(counter: &counter) { splitIndex, split in
            if splitIndex == index { split.fraction = fraction }
        }
    }

    private func visitingSplits(counter: inout Int, _ body: (Int, inout WorkspacePaneSplit) -> Void) -> WorkspacePaneLayout {
        guard case .split(var split) = self else { return self }
        split.leading = split.leading.visitingSplits(counter: &counter, body)
        let splitIndex = counter
        counter += 1
        body(splitIndex, &split)
        split.trailing = split.trailing.visitingSplits(counter: &counter, body)
        return .split(split)
    }

    /// Every pane's content run through `transform`. Contents are unique, so a swap or replacement maps each
    /// pane independently of tree order.
    private func mappingPanes(_ transform: (WorkspacePaneContent) -> WorkspacePaneContent) -> WorkspacePaneLayout {
        switch self {
        case .pane(let content):
            return .pane(transform(content))
        case .split(let split):
            var updated = split
            updated.leading = split.leading.mappingPanes(transform)
            updated.trailing = split.trailing.mappingPanes(transform)
            return .split(updated)
        }
    }
}

private extension ClosedRange<Double> {
    func clamped(_ value: Double) -> Double {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
