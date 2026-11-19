import AppKit

@MainActor
struct TranscriptBookmarkCommandTarget {
    let toggleBookmark: @MainActor () -> Void
    let goToAdjacentBookmark: @MainActor (_ forward: Bool) -> Void
    let contextMenuItems: @MainActor (_ entryID: Int) -> [NSMenuItem]
    var editBookmark: @MainActor () -> Void = {}
    var toggleBookmarkOnEntry: @MainActor (_ entryID: Int) -> Void = { _ in }
    var editBookmarkOnEntry: @MainActor (_ entryID: Int) -> Void = { _ in }
}

@MainActor
final class TranscriptBookmarkTargetRegistry {
    static let shared = TranscriptBookmarkTargetRegistry()

    private let reporters = NSHashTable<TranscriptBookmarkTargetReportingView>.weakObjects()

    func register(_ reporter: TranscriptBookmarkTargetReportingView) {
        reporters.add(reporter)
    }

    func target(keyWindow: NSWindow?) -> TranscriptBookmarkCommandTarget? { keyWindow.flatMap(target(in:)) }

    func target(for view: NSView) -> TranscriptBookmarkCommandTarget? { view.window.flatMap(target(in:)) }

    func target(in window: NSWindow) -> TranscriptBookmarkCommandTarget? {
        reporters.allObjects.first { $0.window === window && $0.isActive && $0.target != nil }?.target
    }
}
