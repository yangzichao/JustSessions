import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// The store's alert as the main window shows it, in a window on screen: clicking its buttons, and a new alert
/// set while the previous one is still closing, as when Try Again fails at once.
@MainActor
@Suite(.serialized)
struct StoreAlertPresentationTests {
    @Test func aRetryThatFailsAtOnceShowsItsOwnAlert() async throws {
        let scenario = try StoreAlertScenario()
        defer { scenario.remove() }

        scenario.store.delete(scenario.session)
        let firstAlert = try await scenario.alertOnScreen(showing: StoreAlertScenario.notFoundMessage)
        #expect(scenario.store.alert?.message == StoreAlertScenario.notFoundMessage)

        try await scenario.click("Try Again", in: firstAlert)
        let retryAlert = try await scenario.alertOnScreen(showing: StoreAlertScenario.connectionLostMessage)
        #expect(scenario.hosts.attempts(on: "devbox") == 2)
        #expect(scenario.store.alert?.message == StoreAlertScenario.connectionLostMessage)

        try await scenario.click("OK", in: retryAlert)
        try await scenario.expectNoAlert()
    }

    @Test func okClosesTheAlertAndClearsIt() async throws {
        let scenario = try StoreAlertScenario()
        defer { scenario.remove() }

        scenario.store.delete(scenario.session)
        let alert = try await scenario.alertOnScreen(showing: StoreAlertScenario.notFoundMessage)
        try await scenario.click("OK", in: alert)

        try await scenario.expectNoAlert()
        #expect(scenario.hosts.attempts(on: "devbox") == 1)
    }

    @Test func aDeletionRightAfterOKShowsItsAlert() async throws {
        let scenario = try StoreAlertScenario()
        defer { scenario.remove() }

        scenario.store.delete(scenario.session)
        let firstAlert = try await scenario.alertOnScreen(showing: StoreAlertScenario.notFoundMessage)
        try await scenario.click("OK", in: firstAlert)
        // Before the first alert has finished closing.
        scenario.store.delete(scenario.session)

        let secondAlert = try await scenario.alertOnScreen(showing: StoreAlertScenario.connectionLostMessage)
        #expect(scenario.store.alert?.message == StoreAlertScenario.connectionLostMessage)
        try await scenario.click("OK", in: secondAlert)
        try await scenario.expectNoAlert()
    }

    /// The tightest timing: a new alert set in the same turn as the click that closes the old one.
    @Test func anAlertSetInTheSameTurnAsOKIsShown() async throws {
        let scenario = try StoreAlertScenario()
        defer { scenario.remove() }

        scenario.store.delete(scenario.session)
        let firstAlert = try await scenario.alertOnScreen(showing: StoreAlertScenario.notFoundMessage)
        try await scenario.click("OK", in: firstAlert)
        scenario.store.showError("Something else went wrong.")

        let secondAlert = try await scenario.alertOnScreen(showing: "Something else went wrong.")
        #expect(scenario.store.alert?.message == "Something else went wrong.")
        try await scenario.click("OK", in: secondAlert)
        try await scenario.expectNoAlert()
    }

    /// An alert that comes while another is on screen, as when a long deletion ends while an unrelated error is
    /// shown, waits until that one is dismissed rather than replacing it unseen.
    @Test func anAlertThatComesWhileAnotherIsShownWaitsForIt() async throws {
        let scenario = try StoreAlertScenario()
        defer { scenario.remove() }

        scenario.store.delete(scenario.session)
        _ = try await scenario.alertOnScreen(showing: StoreAlertScenario.notFoundMessage)
        scenario.store.showError("Something else went wrong.")
        try await Task.sleep(for: .milliseconds(300))
        #expect(scenario.store.alert?.message == StoreAlertScenario.notFoundMessage)

        try await scenario.click("OK", in: try await scenario.alertOnScreen(showing: StoreAlertScenario.notFoundMessage))
        let secondAlert = try await scenario.alertOnScreen(showing: "Something else went wrong.")
        #expect(scenario.store.alert?.message == "Something else went wrong.")
        try await scenario.click("OK", in: secondAlert)
        try await scenario.expectNoAlert()
    }

    @Test func confirmingADeletionThatFailsAtOnceShowsItsAlert() async throws {
        let scenario = try StoreAlertScenario(confirming: true)
        defer { scenario.remove() }

        let confirmation = try await scenario.sheetOnScreen(withButton: SessionDeletionConfirmationText.oneSessionButtonTitle)
        try await scenario.click(SessionDeletionConfirmationText.oneSessionButtonTitle, in: confirmation) {
            scenario.store.isDeletingSessions || scenario.store.alert != nil
        }

        let alert = try await scenario.alertOnScreen(showing: StoreAlertScenario.notFoundMessage)
        #expect(scenario.store.alert?.message == StoreAlertScenario.notFoundMessage)
        try await scenario.click("OK", in: alert)
        try await scenario.expectNoAlert()
    }

    @Test func aClickOnTheWindowAroundTheAlertClosesItAndClearsIt() async throws {
        let scenario = try StoreAlertScenario()
        defer { scenario.remove() }

        scenario.store.delete(scenario.session)
        _ = try await scenario.alertOnScreen(showing: StoreAlertScenario.notFoundMessage)
        try scenario.clickBesideTheSheet()

        try await scenario.expectNoAlert()
    }

    @Test func aClickOnTheWindowAroundTheDeletionConfirmationCancelsIt() async throws {
        let scenario = try StoreAlertScenario(confirming: true)
        defer { scenario.remove() }

        _ = try await scenario.sheetOnScreen(withButton: SessionDeletionConfirmationText.oneSessionButtonTitle)
        try scenario.clickBesideTheSheet()

        try await scenario.expectNoAlert()
        #expect(!scenario.store.isDeletingSessions)
        #expect(scenario.hosts.attempts(on: "devbox") == 0)
    }
}

/// One session on devbox in a store whose deletions there fail at once: the first because the host can't be
/// found, later ones because the connection was lost, so each alert can be told apart. The store's alert, and
/// with `confirming` the deletion dialog asking to delete the session, are shown on a window on screen.
@MainActor
private final class StoreAlertScenario {
    static let notFoundMessage = "devbox couldn't be found. Check the host name and your network or VPN."
    static let connectionLostMessage = "The connection to devbox was lost, for example because the Mac slept or the network changed."

    let sandbox: DeletionSandbox
    let hosts = SimulatedSSHHosts { _, attempt in attempt == 1 ? SimulatedSSHHosts.connectionFailure : SimulatedSSHHosts.connectionLost }
    let store: ConversationStore
    let session: Conversation
    private let window: NSWindow

    init(confirming: Bool = false) throws {
        sandbox = try DeletionSandbox()
        session = try sandbox.savedConversation(onHost: "devbox", title: "Refactor")
        store = sandbox.makeStore(listing: [session], remoteDeletion: hosts.deletion)
        _ = NSApplication.shared
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: StoreAlertHost(
            store: store,
            deletionRequest: confirming ? .conversation(session) : nil
        ))
        window.center()
        window.orderFrontRegardless()
    }

    /// Waits until the window's sheet is an alert showing `message`, and returns it.
    func alertOnScreen(showing message: String) async throws -> NSWindow {
        try await sheetOnScreen { sheet in Self.texts(in: sheet).contains(message) }
    }

    func sheetOnScreen(withButton title: String) async throws -> NSWindow {
        try await sheetOnScreen { sheet in Self.button(titled: title, in: sheet) != nil }
    }

    /// Clicks a button of the store's alert. The alert's own action dismisses it from the store, so a click that
    /// took effect is never repeated; see `click(_:in:until:)`.
    func click(_ title: String, in sheet: NSWindow) async throws {
        let clickedAlertID = store.alert?.id
        try await click(title, in: sheet) { self.store.alert?.id != clickedAlertID }
    }

    /// Clicks the button, then again while `tookEffect` stays false: on a busy machine a click can come while the
    /// sheet is still appearing and be ignored. It checks right after each click, so a click that took effect
    /// returns in the same turn.
    func click(_ title: String, in sheet: NSWindow, until tookEffect: () -> Bool) async throws {
        let clock = ContinuousClock()
        for _ in 1...5 {
            try #require(Self.button(titled: title, in: sheet)).performClick(nil)
            let deadline = clock.now + .seconds(2)
            while !tookEffect(), clock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            if tookEffect() { return }
        }
        Issue.record("Clicking “\(title)” had no effect after 5 tries")
    }

    /// Clicks the window's content beside its sheet, which AppKit alone would only answer with a beep.
    func clickBesideTheSheet() throws {
        NSApp.sendEvent(try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: CGPoint(x: 20, y: 20), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        )))
    }

    /// Lets any closing finish, then expects neither an alert on screen nor one in the store.
    func expectNoAlert() async throws {
        try await expectEventually { window.attachedSheet == nil }
        try await Task.sleep(for: .milliseconds(300))
        #expect(window.attachedSheet == nil)
        #expect(store.alert == nil)
    }

    func remove() {
        if let sheet = window.attachedSheet { window.endSheet(sheet) }
        window.contentView = nil
        window.close()
        sandbox.remove()
    }

    private func sheetOnScreen(where matches: (NSWindow) -> Bool) async throws -> NSWindow {
        let clock = ContinuousClock()
        // At the start of a full run, when every suite starts at once, a shared CI runner can take longer than
        // `expectEventually`'s default 30 seconds to show a sheet: the v1.0.9 release run took 28 seconds here, and
        // v1.0.10's first ran out. Passing runs still return as soon as the sheet shows.
        let deadline = clock.now + .seconds(120)
        while clock.now < deadline {
            if let sheet = window.attachedSheet, sheet.isVisible, matches(sheet) { return sheet }
            try await Task.sleep(for: .milliseconds(20))
        }
        let shown = window.attachedSheet.map { Self.texts(in: $0) } ?? []
        Issue.record("No such sheet on screen; shown: \(shown); store alert: \(String(describing: store.alert))")
        throw CancellationError()
    }

    private static func button(titled title: String, in sheet: NSWindow) -> NSButton? {
        descendants(of: sheet.contentView).compactMap { $0 as? NSButton }.first { $0.title == title }
    }

    private static func texts(in sheet: NSWindow) -> [String] {
        descendants(of: sheet.contentView).compactMap { ($0 as? NSTextField)?.stringValue }
    }

    private static func descendants(of view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants(of: $0) }
    }
}

/// The main window's alert and deletion dialog, as ContentView applies them.
private struct StoreAlertHost: View {
    @ObservedObject var store: ConversationStore
    @State var deletionRequest: SessionDeletionRequest?

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sessionDeletionDialog(for: $deletionRequest, store: store)
            .storeAlert(store)
    }
}
