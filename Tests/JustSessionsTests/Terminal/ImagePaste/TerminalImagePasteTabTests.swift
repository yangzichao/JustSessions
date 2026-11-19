import AppKit
import Foundation
import Testing

@testable import JustSessions

@MainActor
struct TerminalImagePasteTabTests {
    enum Trigger: CaseIterable {
        case rightClickMenuPaste
        case editMenuPaste

        @MainActor
        func paste(in terminalView: any TabTerminalView) {
            switch self {
            case .rightClickMenuPaste: terminalView.paste(terminalView)
            case .editMenuPaste: NSApp.sendAction(#selector(NSText.paste(_:)), to: terminalView, from: NSMenuItem())
            }
        }
    }

    @Test(arguments: TerminalEngine.allCases, Trigger.allCases)
    func onAnSSHHostTheImageIsCopiedThereAndTheCLIGetsItsPath(_ engine: TerminalEngine, _ trigger: Trigger) async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let hostHome = folder.appendingPathComponent("host-home")
        try FileManager.default.createDirectory(at: hostHome, withIntermediateDirectories: true)
        let receivedInput = folder.appendingPathComponent("received-input")
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: .claude,
            projectPath: "/home/me/project",
            action: nil,
            displayTitle: "Tab",
            command: NativeCLICommand(
                executablePath: "/bin/sh",
                arguments: ["-c", "stty raw -echo; exec cat > \"$RECEIVED_INPUT\""],
                workingDirectory: folder.path,
                environment: ["RECEIVED_INPUT=\(receivedInput.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color"]
            ),
            host: .ssh("devbox")
        )
        // Ghostty takes a paste only in a window.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = tab.terminalView
        window.makeFirstResponder(tab.terminalView)
        let png = makePNGData()
        let pasteboard = NSPasteboard.holding([.png: png])
        defer {
            tab.close()
            window.close()
            pasteboard.releaseGlobally()
        }
        tab.terminalView.imagePaste.pasteboard = pasteboard
        let fileDrop = try #require(tab.sshFileDrop)
        fileDrop.copier = .local(home: hostHome)
        fileDrop.connectionSharing = { _ in nil }
        fileDrop.pastedImagesFolder = folder.appendingPathComponent("pasted images")
        tab.startIfNeeded()
        try await expectEventually { FileManager.default.fileExists(atPath: receivedInput.path) }

        trigger.paste(in: tab.terminalView)

        let received = { String(decoding: (try? Data(contentsOf: receivedInput)) ?? Data(), as: UTF8.self) }
        try await expectEventually { received().hasSuffix(" ") }
        let droppedFiles = hostHome.appendingPathComponent(RemoteDroppedFileCopyScript.droppedFilesFolder)
        let copies = try FileManager.default.contentsOfDirectory(atPath: droppedFiles.path)
        try #require(copies.count == 1)
        let hostPath = droppedFiles.appendingPathComponent(copies[0]).appendingPathComponent("pasted-image.png").path
        #expect(received() == TerminalFileDropPaste.escapedPath(hostPath) + " ")
        #expect(try Data(contentsOf: URL(fileURLWithPath: hostPath)) == png)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fileDrop.pastedImagesFolder.path).isEmpty)
    }

    /// Ghostty drops an empty paste, so the tab sends the one Claude Code answers by reading the clipboard itself.
    @Test(arguments: Trigger.allCases)
    func onThisMacAGhosttyTabSendsAnEmptyBracketedPaste(_ trigger: Trigger) async throws {
        let fixture = try GhosttyTabFixture()
        let pasteboard = NSPasteboard.holding([.png: makePNGData()])
        defer {
            fixture.tearDown()
            pasteboard.releaseGlobally()
        }
        fixture.view.imagePaste.pasteboard = pasteboard
        try await fixture.start(printing: "printf '\\033[?2004h'")
        try await expectEventually { fixture.view.isBracketedPasteOn }

        trigger.paste(in: fixture.view)

        try await expectEventually { !fixture.receivedInput.isEmpty }
        #expect(fixture.receivedInput == "\u{1B}[200~\u{1B}[201~")
    }

    /// As SwiftTerm does, nothing goes to a program that didn't turn bracketed paste on, where the markers would be
    /// typed as text.
    @Test func onThisMacAGhosttyTabSendsNothingWithoutBracketedPaste() async throws {
        let fixture = try GhosttyTabFixture()
        let pasteboard = NSPasteboard.holding([.png: makePNGData()])
        defer {
            fixture.tearDown()
            pasteboard.releaseGlobally()
        }
        fixture.view.imagePaste.pasteboard = pasteboard
        try await fixture.start(printing: "printf '\\033[?2004h\\033[?2004l'; touch printed")
        try await expectEventually { FileManager.default.fileExists(atPath: fixture.folder.appendingPathComponent("printed").path) }
        try await Task.sleep(for: .milliseconds(200))

        Trigger.editMenuPaste.paste(in: fixture.view)
        fixture.view.sendAsTyped("x")

        try await expectEventually { !fixture.receivedInput.isEmpty }
        #expect(fixture.receivedInput == "x")
    }

    @Test func aClipboardWithTextIsLeftToTheEngine() throws {
        let fixture = try GhosttyTabFixture()
        let pasteboard = NSPasteboard.holding([.png: makePNGData(), .string: Data("shot.png".utf8)])
        defer {
            fixture.tearDown()
            pasteboard.releaseGlobally()
        }
        fixture.view.imagePaste.pasteboard = pasteboard

        #expect(!fixture.view.pastesClipboardImage())
        #expect(fixture.view.imagePaste.handleClipboardImage() == nil)
    }

}
