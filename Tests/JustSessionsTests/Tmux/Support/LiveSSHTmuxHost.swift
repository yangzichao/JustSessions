import Foundation

@testable import JustSessions

enum LiveSSHTmuxHost {
    static let host = ProcessInfo.processInfo.environment["JUSTSESSIONS_LIVE_SSH_HOST"].flatMap { $0.isEmpty ? nil : $0 }

    @MainActor
    static func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<80 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return condition()
    }

    /// Runs `command` on the host in `sh -l`, whose `~/.profile` gives it the PATH a tab's login shell has, so `tmux`
    /// is the one a tab there runs.
    @discardableResult
    static func ssh(_ host: String, _ command: String, input: String = "") throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = ["-o", "BatchMode=yes", "-o", "RemoteCommand=none", "-T", host, "sh -lc \(ShellQuoting.quoted(command))"]
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        inputPipe.fileHandleForWriting.write(Data(input.utf8))
        try inputPipe.fileHandleForWriting.close()
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: output, as: UTF8.self)
    }

    static func readable(_ bytes: String) -> String {
        bytes.replacingOccurrences(of: "\u{1b}", with: " ESC")
    }
}
