import AppKit
import Foundation
import Testing

@testable import JustSessions

/// A drop on a tab on an SSH host, from the drag to what the tab's CLI receives, whichever engine draws the tab. A
/// local shell stands in for `ssh` and the host, and the tab's process records what it is sent.
@MainActor
struct TerminalSSHFileDropTabTests {
    @Test(arguments: TerminalEngine.allCases)
    func droppedFilesReachTheHostAndTheCLIGetsTheirPathsThere(_ engine: TerminalEngine) async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let hostHome = folder.appendingPathComponent("host-home")
        try FileManager.default.createDirectory(at: hostHome, withIntermediateDirectories: true)
        let receivedInput = folder.appendingPathComponent("received-input")
        let file = try makeDroppedFile(named: "shot 1.png", byteCount: 50_000, in: folder)
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
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = tab.terminalView
        defer {
            tab.close()
            window.close()
        }
        let fileDrop = try #require(tab.sshFileDrop)
        fileDrop.copier = .local(home: hostHome)
        fileDrop.connectionSharing = { _ in nil }
        tab.startIfNeeded()
        try await expectEventually { FileManager.default.fileExists(atPath: receivedInput.path) }

        #expect(tab.terminalView.performDragOperation(FileDragOntoTerminal(paths: [file.path])))

        let received = { String(decoding: (try? Data(contentsOf: receivedInput)) ?? Data(), as: UTF8.self) }
        try await expectEventually { received().hasSuffix(" ") }
        let droppedFiles = hostHome.appendingPathComponent(RemoteDroppedFileCopyScript.droppedFilesFolder)
        let copies = try FileManager.default.contentsOfDirectory(atPath: droppedFiles.path)
        try #require(copies.count == 1)
        let hostPath = droppedFiles.appendingPathComponent(copies[0]).appendingPathComponent("shot 1.png").path
        #expect(received() == TerminalFileDropPaste.escapedPath(hostPath) + " ")
        #expect(try Data(contentsOf: URL(fileURLWithPath: hostPath)) == Data(contentsOf: file))
    }
}
