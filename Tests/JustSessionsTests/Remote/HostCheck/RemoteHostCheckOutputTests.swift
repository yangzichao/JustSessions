import Foundation
import Testing

@testable import JustSessions

struct RemoteHostCheckOutputTests {
    @Test func readsEachAnswerUnderItsMarkerAndIgnoresWhatComesBefore() {
        let output = hostCheckOutput(["shell": "/bin/zsh", "tmux-version": "tmux 3.4\n", "cli-codex-path": ""])

        #expect(output.text("shell") == "/bin/zsh")
        #expect(output.text("tmux-version") == "tmux 3.4")
        #expect(output.text("cli-codex-path") == nil)
        #expect(output.textsByKey["cli-codex-path"] == "")
        #expect(!output.textsByKey.values.contains { $0.contains("Welcome") })
        #expect(output.reachedLoginShell)
    }

    @Test func aScriptTheLoginShellNeverRanHasNoShellAnswer() {
        let output = hostCheckOutput(["rsync-path": "/usr/bin/rsync", "outside-login-shell-done": ""])
        #expect(!output.reachedLoginShell)
    }

    @Test func readsExitStatuses() {
        let output = hostCheckOutput(["folder-exit": "1", "tmux-server-exit": "not a number"])
        #expect(output.exitStatus("folder-exit") == 1)
        #expect(output.exitStatus("tmux-server-exit") == nil)
        #expect(output.exitStatus("missing") == nil)
    }
}
