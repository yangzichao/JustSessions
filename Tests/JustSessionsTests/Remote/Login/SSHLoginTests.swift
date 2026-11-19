import Foundation
import Testing

@testable import JustSessions

/// Connect… logs in the way `ssh` does in Terminal, asking `ssh`'s questions in the app, and keeps the master. A
/// script stands in for `ssh`: it asks for a password through `SSH_ASKPASS`, twice if the first is wrong, and makes the
/// control socket's file when the answer is right. Another stands in for the app as the askpass program.
struct SSHLoginTests {
    static let fakeSSH = """
        #!/bin/sh
        for argument; do
            case "$argument" in ControlPath=*) control_path="${argument#ControlPath=}" ;; esac
        done
        echo "Authorized users only." >&2
        for attempt in 1 2; do
            answer=$("$SSH_ASKPASS" "(me@devbox) Password: ") || exit 255
            if [ "$answer" = "hunter2" ]; then
                : > "$control_path"
                exit 0
            fi
        done
        echo "me@devbox: Permission denied (publickey,password)." >&2
        exit 255
        """

    /// Does what `SSHAskpassRelay` does when `ssh` starts the app.
    static let fakeAskpass = """
        #!/usr/bin/env python3
        import json, os, socket, sys
        connection = socket.socket(socket.AF_UNIX)
        connection.connect(os.environ["JUSTSESSIONS_ASKPASS_SOCKET"])
        request = {"prompt": sys.argv[1], "hint": os.environ.get("SSH_ASKPASS_PROMPT")}
        connection.sendall((json.dumps(request) + "\\n").encode())
        received = b""
        while b"\\n" not in received:
            chunk = connection.recv(4096)
            if not chunk:
                sys.exit(1)
            received += chunk
        answer = json.loads(received.split(b"\\n")[0]).get("answer")
        if answer is None:
            sys.exit(1)
        print(answer)
        """

    private struct Fixture {
        let scripts: URL
        let socketRoot: String
        let connections = SSHLoginConnections(close: { _, _ in })

        init() throws {
            scripts = try makeTemporaryDirectory()
            socketRoot = makeShortSocketFolder()
            try writeExecutableScript(SSHLoginTests.fakeSSH, to: scripts.appendingPathComponent("ssh"))
            try writeExecutableScript(SSHLoginTests.fakeAskpass, to: scripts.appendingPathComponent("askpass"))
        }

        var login: SSHLogin {
            SSHLogin(
                askpassProgram: scripts.appendingPathComponent("askpass").path,
                sshExecutable: scripts.appendingPathComponent("ssh").path,
                socketRoot: socketRoot,
                connections: connections,
                timeout: 120
            )
        }

        var loginFolders: [String] {
            (try? FileManager.default.contentsOfDirectory(atPath: socketRoot)) ?? []
        }

        func remove() {
            try? FileManager.default.removeItem(at: scripts)
            try? FileManager.default.removeItem(atPath: socketRoot)
        }
    }

    /// The login has no idle limit: it stays open until Disconnect, the host's removal, quitting, or a dropped
    /// connection ends it.
    @Test func theMasterStartsWithTheBackgroundSettingsAndMayAsk() {
        #expect(
            SSHLogin.sshArguments(
                host: "devbox", controlPath: "/tmp/justsessions-ssh-501/login-id/master", keystrokeTimingOptions: []
            ) == [
                "-T", "-o", "BatchMode=no", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=10",
                "-o", "ServerAliveCountMax=3", "-o", "RemoteCommand=none", "-o", "ClearAllForwardings=yes",
                "-o", "ControlMaster=yes", "-o", "ControlPath=/tmp/justsessions-ssh-501/login-id/master",
                "-o", "ControlPersist=yes", "devbox", "true",
            ])
    }

    @Test func theRightPasswordKeepsTheLogin() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let asked = LockedValue<[SSHAskpassQuestion]>([])

        let outcome = await fixture.login.logIn(to: "devbox") { question in
            asked.update { $0.append(question) }
            return "hunter2"
        }

        #expect(outcome == .loggedIn)
        #expect(asked.value.map(\.prompt) == ["(me@devbox) Password:"])
        #expect(asked.value.map(\.context) == ["Authorized users only."])
        #expect(asked.value.map(\.kind) == [.secret])
        #expect(fixture.connections.isLoggedIn("devbox"))
        // Only the master's socket stays; what `ssh` printed and the askpass socket are gone.
        let loginFolder = try #require(fixture.loginFolders.first)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.socketRoot + "/" + loginFolder) == ["master"])
    }

    @Test func aWrongPasswordSaysTheLoginWasRefused() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let outcome = await fixture.login.logIn(to: "devbox") { _ in "wrong" }

        #expect(outcome == .failed(.loginRefused))
        #expect(!fixture.connections.isLoggedIn("devbox"))
        #expect(fixture.loginFolders.isEmpty)
    }

    /// `ssh` asks a refused keyboard-interactive answer again with nothing printed; the sheet says it wasn't accepted.
    @Test func aPasswordAskedAgainSaysTheLastWasNotAccepted() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let asked = LockedValue<[SSHAskpassQuestion]>([])

        let outcome = await fixture.login.logIn(to: "devbox") { question in
            asked.update { $0.append(question) }
            return asked.value.count == 1 ? "wrong" : "hunter2"
        }

        #expect(outcome == .loggedIn)
        #expect(asked.value.map(\.isAskedAgain) == [false, true])
    }

    @Test func cancellingAQuestionCancelsTheLogin() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let outcome = await fixture.login.logIn(to: "devbox") { _ in nil }

        #expect(outcome == .cancelled)
        #expect(!fixture.connections.isLoggedIn("devbox"))
        #expect(fixture.loginFolders.isEmpty)
    }

    /// Closing the Add SSH host sheet while it logs in stops `ssh`.
    @Test func cancellingTheTaskStopsTheLogin() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let isAsking = LockedValue(false)

        let login = Task { [login = fixture.login] in
            await login.logIn(to: "devbox") { _ in
                isAsking.update { $0 = true }
                try? await Task.sleep(for: .seconds(60))
                return Task.isCancelled ? nil : "hunter2"
            }
        }
        try await expectEventually { isAsking.value }
        login.cancel()

        #expect(await login.value == .cancelled)
        #expect(!fixture.connections.isLoggedIn("devbox"))
    }
}
