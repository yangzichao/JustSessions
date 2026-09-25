import AppKit
import Carbon.HIToolbox
import Testing
@testable import JustSessions

struct ThisMacTmuxServerTests {
    private let server = ThisMacTmuxServer(executablePath: "/opt/homebrew/bin/tmux", environment: [:])

    @Test func wrapsTheCLIInASessionOfTheAppsOwnServer() throws {
        let cli = NativeCLICommand(
            executablePath: "/Users/me/.local/bin/claude",
            arguments: ["--resume", "abc"],
            workingDirectory: "/Users/me/paper",
            environment: ["COLORTERM=truecolor", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "TMUX=/tmp/tmux-501/default,1,0"]
        )

        let command = server.command(attachingTo: "justsessions-claude-abc", running: cli)

        #expect(command.executablePath == "/opt/homebrew/bin/tmux")
        #expect(Array(command.arguments.prefix(7)) == ["-L", "justsessions", "-f", "/dev/null", "-u", "-T", "RGB"])
        for option in ThisMacTmuxServer.globalOptions {
            #expect(command.arguments.containsSubsequence(["set-option", "-gq", option.name, option.value, ";"]))
        }
        let sessionStart = try #require(command.arguments.firstIndex(of: "new-session"))
        #expect(Array(command.arguments[sessionStart...]) == [
            "new-session", "-A", "-s", "justsessions-claude-abc",
            "-e", "COLORTERM=truecolor", "-e", "PATH=/usr/bin:/bin",
            "--", "/Users/me/.local/bin/claude", "--resume", "abc",
        ])
        // The client starts in the project, so the session does too; it keeps the tab's terminal type.
        #expect(command.workingDirectory == "/Users/me/paper")
        #expect(command.environment == ["COLORTERM=truecolor", "PATH=/usr/bin:/bin", "TERM=xterm-256color"])
    }

    @Test func aCLIWithoutArgumentsRunsThroughEnvRatherThanTheShell() {
        let cli = NativeCLICommand(executablePath: "/Users/me/my tools/codex", arguments: [], workingDirectory: "/tmp", environment: [])

        let arguments = server.command(attachingTo: "justsessions-codex-new-1a2b3c4d", running: cli).arguments

        #expect(Array(arguments.suffix(3)) == ["--", "/usr/bin/env", "/Users/me/my tools/codex"])
    }

    @Test func anArgumentEndingInASemicolonStaysOneArgument() {
        let cli = NativeCLICommand(
            executablePath: "/bin/claude",
            arguments: ["say;", ";", "a;b"],
            workingDirectory: "/tmp",
            environment: ["PROMPT_COMMAND=history -a;"]
        )

        let arguments = server.command(attachingTo: "justsessions-claude-abc", running: cli).arguments

        #expect(arguments.contains("PROMPT_COMMAND=history -a\\;"))
        #expect(Array(arguments.suffix(3)) == ["say\\;", "\\;", "a;b"])
    }

    @Test func tmuxVersionsFromThreePointThreeOnAreSupported() {
        #expect(ThisMacTmuxVersionCheck.isSupported(versionOutput: "tmux 3.6a\n"))
        #expect(ThisMacTmuxVersionCheck.isSupported(versionOutput: "tmux 3.3"))
        #expect(ThisMacTmuxVersionCheck.isSupported(versionOutput: "tmux next-3.8"))
        #expect(ThisMacTmuxVersionCheck.isSupported(versionOutput: "tmux 10.0"))
        #expect(!ThisMacTmuxVersionCheck.isSupported(versionOutput: "tmux 3.2a"))
        #expect(!ThisMacTmuxVersionCheck.isSupported(versionOutput: "tmux 2.9"))
        #expect(!ThisMacTmuxVersionCheck.isSupported(versionOutput: "tmux master"))
        #expect(!ThisMacTmuxVersionCheck.isSupported(versionOutput: ""))
    }

    @Test func paneListingMapsEachSessionToItsCLIProcess() {
        let output = "justsessions-claude-abc 4242\njustsessions-codex-new-1a2b3c4d 77\nbroken line here\nno-pid\n"

        #expect(ThisMacTmuxServer.paneProcessIDs(inListOutput: output) == [
            "justsessions-claude-abc": 4242,
            "justsessions-codex-new-1a2b3c4d": 77,
        ])
    }

    @Test func shiftReturnIsReturnOrKeypadEnterWithShiftAlone() {
        #expect(ShiftReturnKey.matches(keyEvent(keyCode: kVK_Return, modifiers: .shift)))
        #expect(ShiftReturnKey.matches(keyEvent(keyCode: kVK_ANSI_KeypadEnter, modifiers: [.shift, .numericPad])))
        #expect(ShiftReturnKey.matches(keyEvent(keyCode: kVK_Return, modifiers: [.shift, .capsLock])))
        #expect(!ShiftReturnKey.matches(keyEvent(keyCode: kVK_Return, modifiers: [])))
        #expect(!ShiftReturnKey.matches(keyEvent(keyCode: kVK_Return, modifiers: [.shift, .option])))
        #expect(!ShiftReturnKey.matches(keyEvent(keyCode: kVK_ANSI_A, modifiers: .shift)))
    }

    private func keyEvent(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )!
    }
}

private extension Array where Element: Equatable {
    func containsSubsequence(_ subsequence: [Element]) -> Bool {
        guard subsequence.count <= count else { return false }
        return indices.dropLast(subsequence.count - 1).contains { Array(self[$0..<($0 + subsequence.count)]) == subsequence }
    }
}
