import AppKit
import Darwin
import Foundation
import GhosttyTerminal
@testable import JustSessions

/// A Ghostty tab's terminal in a window that is never shown, running a process that records every byte the terminal
/// sends it, while a script of its own prints output. The script can wait for the test with `wait_for <name>`, which
/// returns once the test calls `signal(_:)` with that name.
@MainActor
final class GhosttyTabFixture {
    let view: GhosttyTabTerminalView
    let window: NSWindow
    let appearanceStore: TerminalAppearanceStore
    let themeStore: AppThemeStore
    let folder: URL
    private let settings: IsolatedUserDefaults

    init(
        mode: TerminalAppearanceMode = .light,
        size: NSSize = NSSize(width: 640, height: 400),
        outputHighWaterByteCount: Int = GhosttyOutputBackpressure.defaultHighWaterByteCount,
        outputLowWaterByteCount: Int = GhosttyOutputBackpressure.defaultLowWaterByteCount
    ) throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        folder = try makeTemporaryDirectory()
        appearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        appearanceStore.setMode(mode)
        let frame = NSRect(origin: .zero, size: size)
        view = GhosttyTabTerminalView(
            frame: frame,
            appearanceStore: appearanceStore,
            themeStore: themeStore,
            outputHighWaterByteCount: outputHighWaterByteCount,
            outputLowWaterByteCount: outputLowWaterByteCount
        )
        window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.makeFirstResponder(view)
    }

    /// Starts the process: `script` runs in the background, printing to the terminal, while the input is recorded.
    /// The script starts once Ghostty has laid the terminal out, so its output isn't laid out again.
    func start(printing script: String) async throws {
        let commands = """
            stty raw -echo
            wait_for() { while [ ! -e "$1" ]; do sleep 0.02; done; }
            ( wait_for laid-out; \(script)
            ) &
            exec cat > input
            """
        view.startProcess(
            executable: "/bin/sh",
            args: ["-c", commands],
            environment: ["HOME=\(folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"],
            execName: nil,
            currentDirectory: folder.path
        )
        try await waitForLayout()
        signal("laid-out")
    }

    /// Ghostty lays a new terminal out twice, first at a provisional size; this waits until the grid stays put.
    private func waitForLayout() async throws {
        var lastViewport = view.viewport
        var stableSince = ContinuousClock.now
        let deadline = ContinuousClock.now + .seconds(30)
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
            if view.viewport != lastViewport {
                lastViewport = view.viewport
                stableSince = .now
            } else if lastViewport != nil, ContinuousClock.now - stableSince > .milliseconds(300) {
                return
            }
        }
    }

    func signal(_ name: String) {
        FileManager.default.createFile(atPath: folder.appendingPathComponent(name).path, contents: nil)
    }

    /// Every byte the terminal sent the process so far.
    var receivedInput: String {
        String(decoding: (try? Data(contentsOf: folder.appendingPathComponent("input"))) ?? Data(), as: UTF8.self)
    }

    var screen: String {
        view.inMemorySession.readViewportText() ?? ""
    }

    /// Selects everything, scrollback included, and reads it back.
    func selectAllText() -> String? {
        view.selectAll(nil)
        return view.terminalSurface?.readSelection()
    }

    func tearDown() {
        let processID = view.processID
        if processID > 0 { kill(processID, SIGHUP) }
        view.terminate()
        ClosedTabProcessReaper.reapOnceExited(processID)
        window.contentView = nil
        window.close()
        try? FileManager.default.removeItem(at: folder)
        settings.removeSuite()
    }
}

/// `keyDown` events as a US keyboard sends them.
@MainActor
enum SyntheticKey {
    static func event(keyCode: Int, characters: String, modifiers: NSEvent.ModifierFlags = [], window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )!
    }
}
