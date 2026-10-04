import AppKit
import Testing
@testable import JustSessions

/// Sparkle's Install and Relaunch sends a normal quit request. AppKit rejects that request before consulting the
/// app delegate if Settings is a termination-blocking sheet, even though its changes have already been saved.
// Use the same serialized suite as the menu tests: both register real workspace windows with the shared presenter.
extension AppWideSheetPresentersTests {
    @Test(arguments: [AppWideSheet.settings, .help])
    func settingsAllowsUpdateRelaunchWhileOpen(requestedSheet: AppWideSheet) async throws {
        let workspaceWindow = WorkspaceWindowStandIn()
        defer { workspaceWindow.close() }
        try await workspaceWindow.waitUntilRegistered()

        // Test reopening too: SwiftUI may create a new native sheet each time.
        for _ in 0..<2 {
            workspaceWindow.state.sheet = requestedSheet
            try await expectEventually(timeout: .seconds(5)) { workspaceWindow.window.attachedSheet != nil }
            let settingsWindow = try #require(workspaceWindow.window.attachedSheet)
            try await expectEventually(timeout: .seconds(5)) {
                !settingsWindow.preventsApplicationTerminationWhenModal
            }
            #expect(workspaceWindow.window.preventsApplicationTerminationWhenModal)

            workspaceWindow.state.sheet = nil
            try await expectEventually(timeout: .seconds(5)) { workspaceWindow.window.attachedSheet == nil }
        }

        // Only Settings opts out. Confirmation sheets must retain AppKit's protection.
        let confirmationWindow = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        confirmationWindow.isReleasedWhenClosed = false
        workspaceWindow.window.beginSheet(confirmationWindow, completionHandler: { _ in })
        defer {
            workspaceWindow.window.endSheet(confirmationWindow)
            confirmationWindow.close()
        }
        #expect(confirmationWindow.preventsApplicationTerminationWhenModal)
    }
}
