import AppKit
import Darwin
import Foundation
import Testing

@testable import JustSessions

/// A tab's terminal, drawn by either engine, in a window that is never shown, with the keyboard, running a process that
/// records every byte the terminal sends it.
@MainActor
final class KeyRecordingTerminalFixture {
    let terminalView: any TabTerminalView
    let window: NSWindow
    private let folder: URL
    private let settings: IsolatedUserDefaults
    /// Held here, since a Ghostty controller holds the store weakly.
    private let optionKeyStore: TerminalOptionKeyStore

    /// `optionIsMeta` is the terminal's Option key choice, kept in the fixture's own settings.
    init(engine: TerminalEngine, optionIsMeta: Bool = TerminalOptionKeyStore.defaultOptionIsMeta) throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        folder = try makeTemporaryDirectory()
        let frame = NSRect(x: 0, y: 0, width: 640, height: 400)
        optionKeyStore = TerminalOptionKeyStore(userDefaults: settings.userDefaults)
        optionKeyStore.setOptionIsMeta(optionIsMeta)
        terminalView = engine.makeTabTerminalView(
            frame: frame,
            appearanceStore: TerminalAppearanceStore(userDefaults: settings.userDefaults),
            themeStore: AppThemeStore(userDefaults: settings.userDefaults),
            optionKeyStore: optionKeyStore
        )
        window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = terminalView
        window.makeFirstResponder(terminalView)
    }

    /// Starts the process and waits until the terminal shows it is ready. Raw mode keeps the line discipline from
    /// taking control keys such as Ctrl-U itself.
    func start() async throws {
        terminalView.startProcess(
            executable: "/bin/sh",
            args: ["-c", "stty raw -echo; printf KEY_RECORDER_READY; exec cat > input"],
            environment: ["HOME=\(folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"],
            execName: nil,
            currentDirectory: folder.path
        )
        try await expectEventually { screenText(of: terminalView).contains("KEY_RECORDER_READY") }
    }

    /// Every byte the terminal sent the process so far.
    var receivedInput: String {
        String(decoding: (try? Data(contentsOf: folder.appendingPathComponent("input"))) ?? Data(), as: UTF8.self)
    }

    func tearDown() {
        let processID = terminalView.processID
        if processID > 0 { kill(processID, SIGHUP) }
        terminalView.terminate()
        ClosedTabProcessReaper.reapOnceExited(processID)
        window.contentView = nil
        window.close()
        try? FileManager.default.removeItem(at: folder)
        settings.removeSuite()
    }
}
