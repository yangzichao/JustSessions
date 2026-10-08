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

        try await expectEventually { frontWindow.window.attachedSheet != nil }
        #expect(frontWindow.state.sheet == .help)
        #expect(backWindow.state.sheet == nil)
        #expect(!openedAWorkspaceWindow)
    }

    @Test(arguments: [AppWideSheet.help, .releaseNotes])
    func aMenuRequestSwitchesPagesInTheExistingSettingsSheet(requestedSheet: AppWideSheet) async throws {
        let workspaceWindow = WorkspaceWindowStandIn()
        defer { workspaceWindow.close() }
        try await workspaceWindow.waitUntilRegistered()
        AppWideSheetPresenters.show(.settings) {}
        try await expectEventually { workspaceWindow.window.attachedSheet != nil }
        let originalSheet = try #require(workspaceWindow.window.attachedSheet)

        AppWideSheetPresenters.show(requestedSheet) {}

        #expect(workspaceWindow.state.sheet == requestedSheet)
        #expect(workspaceWindow.window.attachedSheet === originalSheet)
    }

    @Test func aWindowShowingAnotherSheetKeepsIt() async throws {
        let workspaceWindow = WorkspaceWindowStandIn()
        defer { workspaceWindow.close() }
        try await workspaceWindow.waitUntilRegistered()
        let unrelatedSheet = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        unrelatedSheet.isReleasedWhenClosed = false
        workspaceWindow.window.beginSheet(unrelatedSheet, completionHandler: { _ in })
        defer {
            workspaceWindow.window.endSheet(unrelatedSheet)
            unrelatedSheet.close()
        }

        AppWideSheetPresenters.show(.help) {}

        #expect(workspaceWindow.state.sheet == nil)
        #expect(workspaceWindow.window.attachedSheet === unrelatedSheet)
    }

    @Test func withNoWorkspaceWindowOpenTheNewOneShowsTheSheet() async throws {
        let closedWindow = WorkspaceWindowStandIn()
        try await closedWindow.waitUntilRegistered()
        closedWindow.close()
        var newWorkspaceWindow: WorkspaceWindowStandIn?
        defer { newWorkspaceWindow?.close() }

        AppWideSheetPresenters.show(.help) { newWorkspaceWindow = WorkspaceWindowStandIn() }

        let openedWindow = try #require(newWorkspaceWindow)
        try await expectEventually { openedWindow.window.attachedSheet != nil }
        #expect(openedWindow.state.sheet == .help)
        #expect(closedWindow.state.sheet == nil)
        #expect(AppWideSheetPresenters.takeSheetForNewWorkspaceWindow() == nil)
    }
}
