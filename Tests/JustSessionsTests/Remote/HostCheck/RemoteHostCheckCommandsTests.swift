import Foundation
import Testing

@testable import JustSessions

/// The commands are pasted into zsh on this Mac and read again by the host's shell, so anything either would change
/// gets no command.
struct RemoteHostCheckCommandsTests {
    @Test func buildsCommandsForPlainHostsAndValues() {
        #expect(RemoteHostCheckCommands.ssh("me@devbox.local", "true") == "ssh me@devbox.local 'true'")
        #expect(
            RemoteHostCheckCommands.inLoginShell("devbox", "tmux -V", startup: .loginOnly)
                == "ssh devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lc \"tmux -V\"'")
        #expect(
            RemoteHostCheckCommands.shellStartup("devbox", startup: .interactive)
                == "ssh -t devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lic \"echo Startup finished\"'")
    }

    @Test func leavesOutCommandsAShellWouldReadDifferently() {
        #expect(RemoteHostCheckCommands.ssh("dev box", "true") == nil)
        #expect(RemoteHostCheckCommands.ssh("devbox;rm", "true") == nil)
        #expect(RemoteHostCheckCommands.ssh("devbox", "echo 'hi'") == nil)
        #expect(RemoteHostCheckCommands.inLoginShell("devbox", "echo $HOME", startup: .interactive) == nil)
        #expect(RemoteHostCheckCommands.inLoginShell("devbox", "echo \"hi\"", startup: .interactive) == nil)
        #expect(RemoteHostCheckCommands.inLoginShell("devbox", "echo `id`", startup: .interactive) == nil)
        #expect(RemoteHostCheckCommands.shellStartup("dev$box", startup: .interactive) == nil)
    }
}
