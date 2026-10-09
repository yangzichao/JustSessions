import Foundation
import Testing
@testable import JustSessions

/// The check's real commands, run by real bash and zsh in a terminal, as `ssh -t` gives them one, against a temporary
/// home whose startup files start another shell. `script` ends its input at once, so that shell exits rather than
/// wait out the timeout.
struct RemoteShellStartupCheckEndToEndTests {
    @Test func aPlainStartupLetsTheCommandRun() throws {
        let home = try TemporaryHome(files: [".bash_profile": "export EDITOR=vi\n"])
        #expect(home.check(shell: "/bin/bash") == RemoteShellStartupCheckResult(outcome: .interactiveStartupWorks, stoppedAt: nil))
    }

    @Test func aTakeoverInInteractiveShellsFallsBackToALoginShellAndSaysWhere() throws {
        let home = try TemporaryHome(files: [".bash_profile": "export EDITOR=vi\ncase $- in *i*) exec /bin/sh -i ;; esac\n"])
        let result = try #require(home.check(shell: "/bin/bash"))

        #expect(result.outcome == .usesLoginShellOnly)
        #expect(result.stoppedAt?.hasSuffix("/.bash_profile:2: exec /bin/sh -i") == true)
    }

    @Test func aTakeoverInEveryTerminalBlocksTheHost() throws {
        let home = try TemporaryHome(files: [".bash_profile": "if [ -t 1 ]; then exec /bin/sh -i; fi\n"])
        let result = try #require(home.check(shell: "/bin/bash"))

        #expect(result.outcome == .blocked)
        #expect(result.stoppedAt?.hasSuffix("/.bash_profile:1: exec /bin/sh -i") == true)
    }

    @Test func zshSaysWhereItsInteractiveStartupStopped() throws {
        let home = try TemporaryHome(files: [".zshrc": "exec /bin/sh -i\n"])
        let result = try #require(home.check(shell: "/bin/zsh"))

        #expect(result.outcome == .usesLoginShellOnly)
        // zsh traces `exec` by the command it runs.
        #expect(result.stoppedAt?.hasSuffix("/.zshrc:1: /bin/sh -i") == true)
    }

    /// The line the user guide recommends, in a `~/.bashrc` that bash also reads for commands run over SSH, as
    /// Fedora's and Debian's do.
    @Test func aStartupThatLeavesTheAppsShellsAloneLetsTheCommandRun() throws {
        let home = try TemporaryHome(files: [
            ".bash_profile": ". ~/.bashrc\n",
            ".bashrc": "if [[ $- == *i* ]] && [ -z \"$JUSTSESSIONS\" ]; then exec /bin/sh -i; fi\n",
        ])
        #expect(home.check(shell: "/bin/bash", readsBashrcForSSHCommands: true)
            == RemoteShellStartupCheckResult(outcome: .interactiveStartupWorks, stoppedAt: nil))
    }

    /// The shell `sshd` starts for a command reads `~/.bashrc` before the app's command can set `JUSTSESSIONS`, so a
    /// line that checks only for a terminal takes it over, and no startup the app chooses gets past it.
    @Test func aTakeoverInTheShellSSHStartsForACommandBlocksTheHost() throws {
        let home = try TemporaryHome(files: [
            ".bash_profile": ". ~/.bashrc\n",
            ".bashrc": "if [ -z \"$JUSTSESSIONS\" ] && [ -t 1 ]; then exec /bin/sh -i; fi\n",
        ])
        #expect(home.check(shell: "/bin/bash", readsBashrcForSSHCommands: true)
            == RemoteShellStartupCheckResult(outcome: .blocked, stoppedAt: nil))
    }
}

/// A home folder with the given startup files, removed when the test ends.
private final class TemporaryHome {
    let url: URL

    init(files: [String: String]) throws {
        // A short path, as on a real host: bash 3.2 cuts a long trace prefix off before the line number.
        url = URL(fileURLWithPath: "/tmp").appendingPathComponent("js-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for (name, contents) in files {
            try contents.write(to: url.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    /// The host's own shell reads the command, as `sshd` has it do. `readsBashrcForSSHCommands` has that shell, bash,
    /// read `~/.bashrc` though it is not interactive, through `BASH_ENV`, as bash built to do so does under `sshd`.
    func check(shell: String, readsBashrcForSSHCommands: Bool = false) -> RemoteShellStartupCheckResult? {
        var environment = ["HOME": url.path, "SHELL": shell, "TERM": "xterm-256color", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        if readsBashrcForSSHCommands { environment["BASH_ENV"] = url.appendingPathComponent(".bashrc").path }
        let shellEnvironment = environment
        let check = RemoteShellStartupCheck(run: { _, command, timeout in
            BoundedProcessRunner.outcome(
                ofExecutable: "/usr/bin/script",
                arguments: ["-q", "/dev/null", shell, "-c", command],
                environment: shellEnvironment,
                includesStandardError: true,
                timeout: timeout
            )
        }, timeout: 15)
        return check.check(host: "devbox")
    }
}
