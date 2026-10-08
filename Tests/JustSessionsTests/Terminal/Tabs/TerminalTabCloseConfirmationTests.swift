import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// Return answers the dialog that asks before a tab closes, and Escape cancels it. The dialog is shown on a window on
/// screen, as the browser shows it; no tab starts a process, since no terminal is shown.
@MainActor
@Suite(.serialized)
struct TerminalTabCloseConfirmationTests {
    /// A CLI tmux can keep running closes that way: its tab goes, and the CLI can be reattached.
    @Test func returnKeepsATmuxCLIRunning() async throws {
        let scenario = try CloseConfirmationScenario()
        defer { scenario.remove() }
        let tab = scenario.openTab(provider: .claude, tmuxSessionName: "justsessions-close-confirmation-test")

        let sheet = try await scenario.confirmClosing(tab)
        #expect(scenario.defaultButtonTitle(in: sheet) == "Keep running")
        try await scenario.pressReturn(in: sheet) { !scenario.isOpen(tab) }

        #expect(scenario.store.tmuxSessionNamesByHost[.thisMac]?.contains("justsessions-close-confirmation-test") == true)
    }

    @Test(arguments: [(ConversationProvider?.some(.claude), "End session"), (nil, "Close terminal")])
    func returnClosesATabThatCannotKeepRunning(provider: ConversationProvider?, buttonTitle: String) async throws {
        let scenario = try CloseConfirmationScenario()
        defer { scenario.remove() }
        let tab = scenario.openTab(provider: provider, tmuxSessionName: nil)

        let sheet = try await scenario.confirmClosing(tab)
        #expect(scenario.defaultButtonTitle(in: sheet) == buttonTitle)
        try await scenario.pressReturn(in: sheet) { !scenario.isOpen(tab) }
    }

    /// Don't ask again stays in the dialog for a CLI tmux can keep running, and Return with it ticked saves Keep
    /// running, so later closes keep the CLI running without asking.
    @Test func returnWithDontAskAgainTickedSavesKeepRunning() async throws {
        let scenario = try CloseConfirmationScenario()
        defer { scenario.remove() }
        let tab = scenario.openTab(provider: .claude, tmuxSessionName: "justsessions-close-confirmation-test")

        let sheet = try await scenario.confirmClosing(tab)
        try scenario.tick("Don't ask again", in: sheet)
        try await scenario.pressReturn(in: sheet) { !scenario.isOpen(tab) }

        #expect(scenario.tabCloseChoiceSettingsStore.choice == .keepRunning)
    }

    @Test func aTabThatCannotKeepRunningOffersNoDontAskAgain() async throws {
        let scenario = try CloseConfirmationScenario()
        defer { scenario.remove() }
        let sheet = try await scenario.confirmClosing(scenario.openTab(provider: .claude, tmuxSessionName: nil))

        #expect(!scenario.hasButton(titled: "Don't ask again", in: sheet))
    }

    @Test func escapeLeavesTheTabOpen() async throws {
        let scenario = try CloseConfirmationScenario()
        defer { scenario.remove() }
        let tab = scenario.openTab(provider: .claude, tmuxSessionName: nil)

        let sheet = try await scenario.confirmClosing(tab)
        try await scenario.pressEscape(in: sheet)

        #expect(scenario.isOpen(tab))
    }
}

@MainActor
private final class CloseConfirmationScenario {
    /// A dialog shows in well under a second, but at the start of a full run, when every suite starts at once, the
    /// main thread can stay busy for far longer; 20 seconds once ran out. Passing runs still finish at once.
    private static let timeoutSeconds = 120

    let store: ConversationStore
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    private let settings: IsolatedUserDefaults
    private let window: NSWindow
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))

    init() throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        tabCloseChoiceSettingsStore = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        window.orderFrontRegardless()
    }

    func openTab(provider: ConversationProvider?, tmuxSessionName: String?) -> TerminalSession {
        let tab = TerminalSession(
            conversation: nil, provider: provider, projectPath: "/tmp", action: nil, displayTitle: "Tab",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            tmuxSessionName: tmuxSessionName
        )
        store.openTerminal(tab)
        return tab
    }

    func isOpen(_ tab: TerminalSession) -> Bool {
        store.terminalSessions.contains { $0.id == tab.id }
    }

    /// Asks to close `tab`, as its close button does, and returns the dialog once it is on screen.
    func confirmClosing(_ tab: TerminalSession) async throws -> NSWindow {
        hostingView.rootView = AnyView(CloseConfirmationHost(
            store: store, tabCloseChoiceSettingsStore: tabCloseChoiceSettingsStore, closingSessionID: tab.id
        ))
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(Self.timeoutSeconds)
        while clock.now < deadline {
            hostingView.layoutSubtreeIfNeeded()
            if let sheet = window.attachedSheet, sheet.isVisible, !Self.buttons(in: sheet).isEmpty { return sheet }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("The close confirmation never appeared")
        throw CancellationError()
    }

    /// The button Return presses, or a description of every button when none has Return.
    func defaultButtonTitle(in sheet: NSWindow) -> String {
        let buttons = Self.buttons(in: sheet)
        return buttons.first { $0.keyEquivalent == "\r" }?.title
            ?? "none; buttons: " + buttons.map { "\($0.title) [\($0.keyEquivalent.debugDescription)]" }.joined(separator: ", ")
    }

    func hasButton(titled title: String, in sheet: NSWindow) -> Bool {
        Self.buttons(in: sheet).contains { $0.title == title }
    }

    /// Ticks a checkbox in the dialog, such as Don't ask again, leaving it as a click does: on, with its action sent.
    /// Not with `performClick`, whose event tracking loop runs blocks queued for the main run loop; one of them stops
    /// the run loop, which ends this test process, silently, partway through the next test.
    func tick(_ title: String, in sheet: NSWindow) throws {
        let checkbox = try #require(Self.buttons(in: sheet).first { $0.title == title })
        checkbox.state = .on
        if let action = checkbox.action { #expect(checkbox.sendAction(action, to: checkbox.target)) }
    }

    /// Presses Return as the keyboard does, through the dialog's key equivalents, then waits for `tookEffect`.
    func pressReturn(in sheet: NSWindow, until tookEffect: () -> Bool) async throws {
        try press("\r", keyCode: 36, in: sheet)
        try await expectEventually(timeout: .seconds(Self.timeoutSeconds)) { tookEffect() }
    }

    func pressEscape(in sheet: NSWindow) async throws {
        try press("\u{1B}", keyCode: 53, in: sheet)
        try await expectEventually(timeout: .seconds(Self.timeoutSeconds)) { self.window.attachedSheet == nil }
    }

    private func press(_ characters: String, keyCode: UInt16, in sheet: NSWindow) throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: sheet.windowNumber, context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: keyCode
        ))
        #expect(sheet.performKeyEquivalent(with: event), "No button answers \(characters.debugDescription)")
    }

    func remove() {
        if let sheet = window.attachedSheet { window.endSheet(sheet) }
        store.closeAllTerminals()
        hostingView.rootView = AnyView(EmptyView())
        window.close()
        settings.removeSuite()
    }

    private static func buttons(in sheet: NSWindow) -> [NSButton] {
        descendants(of: sheet.contentView).compactMap { $0 as? NSButton }.filter { !$0.title.isEmpty }
    }

    private static func descendants(of view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants(of: $0) }
    }
}

/// The browser's close confirmation, asking about `closingSessionID` from the start.
private struct CloseConfirmationHost: View {
    @ObservedObject var store: ConversationStore
    let tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore
    @State var closingSessionID: UUID?

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(TerminalTabCloseConfirmation(
                store: store, closingSessionID: $closingSessionID, tabCloseChoiceSettingsStore: tabCloseChoiceSettingsStore
            ))
    }
}
