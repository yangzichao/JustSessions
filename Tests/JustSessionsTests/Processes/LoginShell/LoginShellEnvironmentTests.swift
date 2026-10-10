import Foundation
import Testing
@testable import JustSessions

struct LoginShellEnvironmentTests {
    @Test func parsePathKeepsOnlyAbsoluteDirectories() {
        let directories = LoginShellEnvironment.parsePathDirectories("/opt/homebrew/bin::.:relative/bin:/usr/bin\n")

        #expect(directories == ["/opt/homebrew/bin", "/usr/bin"])
    }

    @Test func readsWhatTheRcFilesSetUp() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        // Stands in for zsh: exports what an rc file would, then runs the `-c` command ($4).
        let fakeShell = try writeExecutableScript("""
        #!/bin/sh
        PATH="/from/rc/file:/usr/bin"
        SSH_AUTH_SOCK="/Users/me/Library/Group Containers/agent.sock"
        MULTILINE_VALUE="first
        second=line"
        export PATH SSH_AUTH_SOCK MULTILINE_VALUE
        eval "$4"
        """, to: root.appendingPathComponent("fake-shell"))

        let variables = LoginShellEnvironment.readVariables(shellPath: fakeShell.path, timeout: 5)

        #expect(variables["PATH"] == "/from/rc/file:/usr/bin")
        #expect(variables["SSH_AUTH_SOCK"] == "/Users/me/Library/Group Containers/agent.sock")
        #expect(variables["MULTILINE_VALUE"] == "first\nsecond=line")
        #expect(LoginShellEnvironment.parsePathDirectories(variables["PATH"] ?? "") == ["/from/rc/file", "/usr/bin"])
    }

    @Test func hungLoginShellTimesOutWithNothing() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let hungShell = try writeExecutableScript("""
        #!/bin/sh
        trap '' TERM
        sleep 30
        """, to: root.appendingPathComponent("hung-shell"))

        let startedAt = Date()
        let variables = LoginShellEnvironment.readVariables(shellPath: hungShell.path, timeout: 0.5)

        #expect(variables.isEmpty)
        #expect(Date().timeIntervalSince(startedAt) < 5)
    }

    @Test func entriesWithoutANameAreSkipped() {
        let output = Data("A=1\u{0}=no-name\u{0}not-an-entry\u{0}B=x=y\u{0}".utf8)

        #expect(LoginShellEnvironment.parseVariables(output) == ["A": "1", "B": "x=y"])
    }
}
