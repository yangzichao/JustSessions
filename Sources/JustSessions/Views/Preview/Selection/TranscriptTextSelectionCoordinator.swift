import AppKit
import Combine
import SwiftUI

/// AppKit keeps a selection inside one text view.
@MainActor
final class TranscriptTextSelectionCoordinator {
    private final class RegisteredView {
        weak var view: TranscriptTextView?
        init(_ view: TranscriptTextView) { self.view = view }
    }

    private var registeredViews: [TranscriptTextSelectionKey: RegisteredView] = [:]
    private var orderedKeys: [TranscriptTextSelectionKey]?
    private(set) var selection: TranscriptTextSelection?
    var isTracking = false
    let trackingEnded = PassthroughSubject<Void, Never>()
    var pasteboard = NSPasteboard.general
    var eventSource = TranscriptTextSelectionEventSource.windowQueue
    private weak var selectionWindow: NSWindow?
    private var windowObservations: Set<AnyCancellable> = []

    func register(_ view: TranscriptTextView) {
        guard let key = view.selectionKey else { return }
        if registeredViews[key]?.view !== view {
            registeredViews[key] = RegisteredView(view)
            orderedKeys = nil
        }
        applySelection(to: view)
    }

    func unregister(_ view: TranscriptTextView) {
        guard let key = view.selectionKey, let registeredView = registeredViews[key],
            registeredView.view === view || registeredView.view == nil
        else { return }
        registeredViews[key] = nil
        orderedKeys = nil
    }

    func view(for key: TranscriptTextSelectionKey) -> TranscriptTextView? { registeredViews[key]?.view }

    var orderedViews: [(key: TranscriptTextSelectionKey, view: TranscriptTextView)] {
        let keys = orderedKeys ?? registeredViews.keys.sorted()
        orderedKeys = keys
        return keys.compactMap { key in registeredViews[key]?.view.map { (key, $0) } }
    }

    func select(_ newSelection: TranscriptTextSelection?, in window: NSWindow?) {
        selection = newSelection
        if let window { observeKeyStatus(of: window) }
        applySelection()
    }

    func applySelection() {
        for (_, view) in orderedViews { applySelection(to: view) }
    }

    func applySelection(to view: TranscriptTextView) {
        guard let key = view.selectionKey else { return }
        let range = selection?.range(in: key, length: view.textLength) ?? NSRange(location: 0, length: 0)
        if view.selectedRange() != range { view.setSelectedRange(range) }
    }

    func clearSelection() {
        guard selection != nil else { return }
        select(nil, in: nil)
    }

    func adoptSelection(of view: TranscriptTextView) {
        guard let key = view.selectionKey else { return }
        let range = view.selectedRange()
        select(
            TranscriptTextSelection(
                anchor: TranscriptTextSelectionPosition(key: key, offset: range.location),
                focus: TranscriptTextSelectionPosition(key: key, offset: NSMaxRange(range))
            ), in: view.window)
    }

    func selectAll() {
        let views = orderedViews
        guard let first = views.first, let last = views.last else { return }
        select(
            TranscriptTextSelection(
                anchor: TranscriptTextSelectionPosition(key: first.key, offset: 0),
                focus: TranscriptTextSelectionPosition(key: last.key, offset: last.view.textLength)
            ), in: first.view.window)
    }

    func copiedText() -> String? {
        guard let selection, selection.spansSeveralBlocks else { return nil }
        let pieces = orderedViews.compactMap { key, view -> TranscriptTextSelectionCopy.Piece? in
            let range = selection.range(in: key, length: view.textLength)
            guard range.length > 0 else { return nil }
            return TranscriptTextSelectionCopy.Piece(
                key: key, role: view.copyRole, text: (view.string as NSString).substring(with: range),
                startsAtBlockStart: range.location == 0
            )
        }
        return TranscriptTextSelectionCopy.text(of: pieces)
    }

    var drawsSelectionEmphasized: Bool {
        guard let window = selectionWindow, window.isKeyWindow,
            let firstResponder = window.firstResponder as? TranscriptTextView
        else { return false }
        return firstResponder.selectionCoordinator === self
    }

    func redrawSelection() {
        for (_, view) in orderedViews where view.selectedRange().length > 0 { view.needsDisplay = true }
    }

    private func observeKeyStatus(of window: NSWindow) {
        guard window !== selectionWindow else { return }
        selectionWindow = window
        windowObservations = [
            NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification, object: window)
                .sink { [weak self] _ in MainActor.assumeIsolated { self?.redrawSelection() } },
            NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification, object: window)
                .sink { [weak self] _ in MainActor.assumeIsolated { self?.redrawSelection() } },
        ]
    }
}

extension EnvironmentValues {
    @Entry var transcriptTextSelection: TranscriptTextSelectionCoordinator?
}
