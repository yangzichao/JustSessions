import AppKit
import Testing
@testable import JustSessions

/// Right-clicking the Dock icon offers New Window, in the app's language, which opens a workspace window.
@MainActor
struct WorkspaceDockMenuTests {
    @Test func theMenuOffersNewWindowInTheAppLanguage() {
        let dockMenu = WorkspaceDockMenu()

        #expect(dockMenu.makeMenu(language: AppInterfaceLanguage(identifier: "en")).items.map(\.title) == ["New Window"])
        #expect(dockMenu.makeMenu(language: AppInterfaceLanguage(identifier: "zh-Hans")).items.map(\.title) == ["新建窗口"])
    }

    @Test func newWindowOpensAWorkspaceWindow() throws {
        let dockMenu = WorkspaceDockMenu()
        var openedWindowCount = 0
        dockMenu.openWorkspaceWindow = { openedWindowCount += 1 }
        let menu = dockMenu.makeMenu(language: AppInterfaceLanguage(identifier: "en"))
        let newWindowItem = try #require(menu.items.first { $0.title == "New Window" })
        let action = try #require(newWindowItem.action)

        #expect(NSApplication.shared.sendAction(action, to: newWindowItem.target, from: newWindowItem))

        #expect(openedWindowCount == 1)
    }
}
