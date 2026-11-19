import AppKit
import Foundation
import SwiftUI
import Testing

@testable import JustSessions

/// The tab bar drawn with a split of one project's tabs in its group and a split across projects as a unit of its own
/// between the groups: the latter is underlined half in each of its tabs' project color, the colors the groups of
/// those projects have. Set `JUSTSESSIONS_THEME_SCREENSHOTS` to a directory to keep the renderings.
@MainActor
struct WorkspaceTabBarRenderingTests {
    private static let barWidth: CGFloat = 760

    @Test(arguments: [ColorScheme.light, .dark])
    func aSplitAcrossProjectsIsUnderlinedHalfInEachProjectsColor(colorScheme: ColorScheme) async throws {
        let (store, cleanUp) = try makeStore()
        defer { cleanUp() }
        let app = open(store, makeTab(projectPath: "/tmp/app"))
        let secondApp = open(store, makeTab(projectPath: "/tmp/app"))
        let thirdApp = open(store, makeTab(projectPath: "/tmp/app"))
        let tools = open(store, makeTab(projectPath: "/tmp/tools"))
        let secondTools = open(store, makeTab(projectPath: "/tmp/tools"))
        store.selectTerminal(secondApp.id)
        store.splitSelectedTerminal(with: thirdApp.id)
        store.selectTerminal(app.id)
        store.splitSelectedTerminal(with: secondTools.id)
        let splitAcrossProjects = try #require(store.shownSplit)
        try #require(splitAcrossProjects.spansProjects)
        try #require(
            store.tabGroupKeys == [
                app.projectDirectoryKey, app.projectDirectoryKey,
                splitAcrossProjects.groupKey, splitAcrossProjects.groupKey,
                tools.projectDirectoryKey,
            ])
        let schemeName = colorScheme == .dark ? "dark" : "light"

        // The split across projects shows, both its tabs active.
        let shownFixture = makeFixture(store: store, colorScheme: colorScheme)
        _ = try await shownFixture.capture(named: "tab-bar-split-across-projects-shown-\(schemeName)")

        // The split of one project's tabs shows; the split across projects sits between the groups, inactive, so its
        // underline is in sight under both its tabs.
        store.selectTerminal(secondApp.id)
        let fixture = makeFixture(store: store, colorScheme: colorScheme)
        let bitmap = try await fixture.capture(named: "tab-bar-split-across-projects-\(schemeName)")
        defer {
            fixture.close()
            shownFixture.close()
        }
        let layout = TabDragBetweenWindows.shared.layouts.layout(of: store)
        let appSpan = try #require(layout.groupSpans[app.projectDirectoryKey])
        let splitSpan = try #require(layout.groupSpans[splitAcrossProjects.groupKey])
        let toolsSpan = try #require(layout.groupSpans[tools.projectDirectoryKey])
        #expect(appSpan.minX < splitSpan.minX && splitSpan.minX + splitSpan.width < toolsSpan.minX)

        let scale = Double(bitmap.pixelsWide) / Self.barWidth
        let underlineRow = bitmap.pixelsHigh - 1
        func underlineColor(atX x: CGFloat) throws -> UInt32 {
            hexValue(of: try #require(bitmap.colorAt(x: Int(x * scale), y: underlineRow)))
        }
        // Under the app group's label and the tools tab, where no active tab covers the line.
        let appColor = try underlineColor(atX: appSpan.minX + 8)
        let toolsColor = try underlineColor(atX: toolsSpan.midX)
        let leftHalfColor = try underlineColor(atX: splitSpan.minX + splitSpan.width / 4)
        let rightHalfColor = try underlineColor(atX: splitSpan.minX + splitSpan.width * 3 / 4)

        #expect(appColor != toolsColor, "\(schemeName): the two projects have different colors")
        #expect(matches(leftHalfColor, appColor), "\(schemeName): the left tab's half is in its project's color")
        #expect(matches(rightHalfColor, toolsColor), "\(schemeName): the right tab's half is in its project's color")
    }

    // MARK: - Helpers

    private func makeFixture(store: ConversationStore, colorScheme: ColorScheme) -> ThemeSurfaceRenderingFixture {
        let bar = WorkspaceTabBar(
            store: store, leadingClearance: 0, onRenameConversation: { _ in }, onNewSession: {},
            onCloseTerminal: { _ in }, onDeleteConversation: { _ in }, onCloseTabGroup: { _, _ in }
        )
        .frame(width: Self.barWidth)
        return ThemeSurfaceRenderingFixture(
            content: AnyView(bar),
            size: CGSize(width: Self.barWidth, height: WorkspaceTabMetrics.topInset + WorkspaceTabMetrics.height),
            colorScheme: colorScheme
        )
    }

    /// Within rounding of a channel, as rasterization may round the solid underline differently from the swatch.
    private func matches(_ color: UInt32, _ reference: UInt32) -> Bool {
        [16, 8, 0].allSatisfy { shift in abs(Int((color >> shift) & 0xFF) - Int((reference >> shift) & 0xFF)) <= 2 }
    }

    private func hexValue(of color: NSColor) -> UInt32 {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].reduce(0) { result, component in
            result << 8 | UInt32((component * 255).rounded())
        }
    }

    private func makeStore() throws -> (ConversationStore, () -> Void) {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        return (
            store,
            {
                store.closeAllTerminals()
                isolatedUserDefaults.removeSuite()
            }
        )
    }

    private func open(_ store: ConversationStore, _ tab: TerminalSession) -> TerminalSession {
        store.openTerminal(tab)
        return tab
    }

    private func makeTab(projectPath: String) -> TerminalSession {
        TerminalSession(
            engine: .swiftTerm,
            conversation: nil,
            provider: .claude,
            projectPath: projectPath,
            action: .resume,
            displayTitle: "Tab in \(projectPath)",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
    }
}
