import AppKit
import Testing

@testable import JustSessions

@MainActor
struct TranscriptBookmarkTargetRegistryTests {
    private let registry = TranscriptBookmarkTargetRegistry()

    @Test func theKeyWindowsActiveReaderAnswers() {
        var toggleCount = 0
        let readerWindow = window(showing: target(onToggle: { toggleCount += 1 }))

        registry.target(keyWindow: readerWindow)?.toggleBookmark()

        #expect(toggleCount == 1)
    }

    @Test func aPreviewBehindATabDoesNotAnswer() {
        let previewWindow = window(showing: target(), isActive: false)
        #expect(registry.target(keyWindow: previewWindow) == nil)
    }

    @Test func aReaderWithoutBookmarksDoesNotAnswer() {
        let readerWindow = window(showing: nil)
        #expect(registry.target(keyWindow: readerWindow) == nil)
    }

    @Test func aSheetOrOtherKeyWindowFindsNothing() {
        let readerWindow = window(showing: target())
        #expect(registry.target(keyWindow: readerWindow) != nil)

        #expect(registry.target(keyWindow: plainWindow()) == nil)
        #expect(registry.target(keyWindow: nil) == nil)
    }

    @Test func aTextViewFindsItsOwnWindowsReader() throws {
        var readerToggleCount = 0
        var otherToggleCount = 0
        let readerWindow = window(showing: target(onToggle: { readerToggleCount += 1 }))
        let otherWindow = window(showing: target(onToggle: { otherToggleCount += 1 }))
        let textView = NSView()
        try #require(readerWindow.contentView).addSubview(textView)

        registry.target(for: textView)?.toggleBookmark()

        #expect(readerToggleCount == 1)
        #expect(otherToggleCount == 0)
        #expect(registry.target(keyWindow: otherWindow) != nil)
        #expect(registry.target(for: NSView()) == nil)
    }

    @Test func aSelectedTabAnswersAndThePreviewBehindItDoesNot() {
        var answered: [String] = []
        let workspaceWindow = plainWindow()
        let preview = addReporter(to: workspaceWindow, target: target(onToggle: { answered.append("preview") }), isActive: false)
        let tab = addReporter(to: workspaceWindow, target: target(onToggle: { answered.append("tab") }), isActive: true)

        registry.target(keyWindow: workspaceWindow)?.toggleBookmark()
        preview.isActive = true
        tab.isActive = false
        registry.target(keyWindow: workspaceWindow)?.toggleBookmark()

        #expect(answered == ["tab", "preview"])
    }

    private func target(onToggle: @escaping @MainActor () -> Void = {}) -> TranscriptBookmarkCommandTarget {
        TranscriptBookmarkCommandTarget(toggleBookmark: onToggle, goToAdjacentBookmark: { _ in }, contextMenuItems: { _ in [] })
    }

    private func window(showing target: TranscriptBookmarkCommandTarget?, isActive: Bool = true) -> NSWindow {
        let window = plainWindow()
        addReporter(to: window, target: target, isActive: isActive)
        return window
    }

    @discardableResult
    private func addReporter(to window: NSWindow, target: TranscriptBookmarkCommandTarget?, isActive: Bool)
        -> TranscriptBookmarkTargetReportingView
    {
        let reporter = TranscriptBookmarkTargetReportingView()
        reporter.registry = registry
        reporter.target = target
        reporter.isActive = isActive
        window.contentView?.addSubview(reporter)
        return reporter
    }

    private func plainWindow() -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: true)
    }
}
