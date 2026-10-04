import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// Settings and Help from the app menu show as a sheet on the frontmost workspace window. Windows are on screen, which
/// SwiftUI needs before it attaches a sheet.
@MainActor
@Suite(.serialized)
struct AppWideSheetPresentersTests {
    @Test func theMenuShowsTheSheetOnTheFrontmostWorkspaceWindowOnly() async throws {
        let backWindow = WorkspaceWindowStandIn()
        defer { backWindow.close() }
        try await backWindow.waitUntilRegistered()
        let frontWindow = WorkspaceWindowStandIn()
        defer { frontWindow.close() }
        try await frontWindow.waitUntilRegistered()
        var openedAWorkspaceWindow = false

        AppWideSheetPresenters.show(.help) { openedAWorkspaceWindow = true }

        try await expectEventually(timeout: .seconds(5)) { frontWindow.window.attachedSheet != nil }
        #expect(frontWindow.state.sheet == .help)
        #expect(backWindow.state.sheet == nil)
        #expect(!openedAWorkspaceWindow)
    }

    @Test func aWindowAlreadyShowingASheetKeepsIt() async throws {
        let workspaceWindow = WorkspaceWindowStandIn()
        defer { workspaceWindow.close() }
        try await workspaceWindow.waitUntilRegistered()
        AppWideSheetPresenters.show(.help) {}
        try await expectEventually(timeout: .seconds(5)) { workspaceWindow.window.attachedSheet != nil }

        AppWideSheetPresenters.show(.settings) {}

        #expect(workspaceWindow.state.sheet == .help)
    }

    @Test func withNoWorkspaceWindowOpenTheNewOneShowsTheSheet() async throws {
        let closedWindow = WorkspaceWindowStandIn()
        try await closedWindow.waitUntilRegistered()
        closedWindow.close()
        var newWorkspaceWindow: WorkspaceWindowStandIn?
        defer { newWorkspaceWindow?.close() }

        AppWideSheetPresenters.show(.help) { newWorkspaceWindow = WorkspaceWindowStandIn() }

        let openedWindow = try #require(newWorkspaceWindow)
        try await expectEventually(timeout: .seconds(5)) { openedWindow.window.attachedSheet != nil }
        #expect(openedWindow.state.sheet == .help)
        #expect(closedWindow.state.sheet == nil)
        #expect(AppWideSheetPresenters.takeSheetForNewWorkspaceWindow() == nil)
    }
}

/// A window on screen that shows Settings and Help the way a workspace window does.
@MainActor
private final class WorkspaceWindowStandIn {
    let state = AppWideSheetState()
    let window: NSWindow

    init() {
        _ = NSApplication.shared
        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 700, height: 640),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AppWideSheetHostingStandIn(state: state))
        window.center()
        window.orderFrontRegardless()
    }

    /// SwiftUI builds the view that registers the window on its first update, after the window is on screen.
    func waitUntilRegistered() async throws {
        try await expectEventually(timeout: .seconds(5)) { containsRegistrationView(window.contentView) }
    }

    func close() {
        window.close()
    }

    private func containsRegistrationView(_ view: NSView?) -> Bool {
        guard let view else { return false }
        return view is AppWideSheetWindowRegistrationView || view.subviews.contains { containsRegistrationView($0) }
    }
}

@MainActor
private final class AppWideSheetState: ObservableObject {
    @Published var sheet: AppWideSheet?
}

private struct AppWideSheetHostingStandIn: View {
    @ObservedObject var state: AppWideSheetState

    var body: some View {
        Color.clear.showsAppWideSheets($state.sheet)
    }
}
