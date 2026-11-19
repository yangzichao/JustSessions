import AppKit
import SwiftUI
import Testing

@testable import JustSessions

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
        scenario.store.delete(scenario.session)

        let secondAlert = try await scenario.alertOnScreen(showing: StoreAlertScenario.connectionLostMessage)
        #expect(scenario.store.alert?.message == StoreAlertScenario.connectionLostMessage)
        try await scenario.click("OK", in: secondAlert)
        try await scenario.expectNoAlert()
    }

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
        window.contentView = NSHostingView(
            rootView: StoreAlertHost(
                store: store,
                deletionRequest: confirming ? .conversation(session) : nil
            ))
        window.center()
        window.orderFrontRegardless()
    }

    func alertOnScreen(showing message: String) async throws -> NSWindow {
        try await sheetOnScreen { sheet in Self.texts(in: sheet).contains(message) }
    }

    func sheetOnScreen(withButton title: String) async throws -> NSWindow {
        try await sheetOnScreen { sheet in Self.button(titled: title, in: sheet) != nil }
    }

    func click(_ title: String, in sheet: NSWindow) async throws {
        let clickedAlertID = store.alert?.id
        try await click(title, in: sheet) { self.store.alert?.id != clickedAlertID }
    }

    func click(_ title: String, in sheet: NSWindow, until tookEffect: () -> Bool) async throws {
        let clock = ContinuousClock()
        let giveUpAt = clock.now + .seconds(120)
        var tries = 0
        while clock.now < giveUpAt {
            try #require(Self.button(titled: title, in: sheet)).performClick(nil)
            tries += 1
            let deadline = clock.now + .seconds(2)
            while !tookEffect(), clock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            if tookEffect() { return }
        }
        Issue.record("Clicking “\(title)” had no effect after \(tries) tries")
    }

    func clickBesideTheSheet() throws {
        NSApp.sendEvent(
            try #require(
                NSEvent.mouseEvent(
                    with: .leftMouseDown, location: CGPoint(x: 20, y: 20), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 1
                )))
    }

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

private struct StoreAlertHost: View {
    let store: ConversationStore
    @State var deletionRequest: SessionDeletionRequest?

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sessionDeletionDialog(for: $deletionRequest, store: store)
            .storeAlert(store)
    }
}
