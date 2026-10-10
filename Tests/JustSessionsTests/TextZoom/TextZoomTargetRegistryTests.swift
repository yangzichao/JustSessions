import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TextZoomTargetRegistryTests {
    private let registry = TextZoomTargetRegistry()

    @Test func theKeyWorkspaceWindowDecides() {
        let terminalWindow = window(showing: .terminals)
        let previewWindow = window(showing: .conversation)
        #expect(target(keyWindow: terminalWindow, mainWindow: terminalWindow) == .terminals)
        #expect(target(keyWindow: previewWindow, mainWindow: previewWindow) == .conversation)
    }

    @Test func aSheetOrPopoverLeavesItToTheMainWindow() {
        let terminalWindow = window(showing: .terminals)
        #expect(target(keyWindow: plainWindow(), mainWindow: terminalWindow) == .terminals)
    }

    @Test func aReadWindowShowsAConversation() {
        let readWindow = plainWindow()
        let terminalWindow = window(showing: .terminals)
        let found = registry.target(keyWindow: readWindow, mainWindow: terminalWindow) { $0 === readWindow }
        #expect(found == .conversation)
    }

    @Test func theTargetFollowsWhatTheWindowShows() {
        let workspaceWindow = window(showing: .conversation)
        let reporter = workspaceWindow.contentView?.subviews.first as? TextZoomTargetReportingView
        reporter?.target = .terminals
        #expect(target(keyWindow: workspaceWindow, mainWindow: workspaceWindow) == .terminals)
    }

    @Test func withoutAWorkspaceWindowNothingIsSized() {
        #expect(target(keyWindow: nil, mainWindow: nil) == nil)
        #expect(target(keyWindow: plainWindow(), mainWindow: nil) == nil)
    }

    private func target(keyWindow: NSWindow?, mainWindow: NSWindow?) -> TextZoomTarget? {
        registry.target(keyWindow: keyWindow, mainWindow: mainWindow) { _ in false }
    }

    private func window(showing target: TextZoomTarget) -> NSWindow {
        let window = plainWindow()
        let reporter = TextZoomTargetReportingView()
        reporter.registry = registry
        reporter.target = target
        window.contentView?.addSubview(reporter)
        return window
    }

    private func plainWindow() -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: true)
    }
}
