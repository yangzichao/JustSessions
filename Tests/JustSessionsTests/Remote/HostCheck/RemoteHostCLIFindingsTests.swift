import Foundation
import Testing

@testable import JustSessions

struct RemoteHostCLIFindingsTests {
    @Test func aCLIThatPrintsItsVersionPasses() throws {
        let output = hostCheckOutput([
            "cli-codex-path": "/home/me/.local/bin/codex",
            "cli-codex-version": "codex-cli 0.50.0",
            "cli-codex-version-exit": "0",
        ])

        let codex = try #require(findings(in: output).first { $0.id == "cli-codex" })

        #expect(codex.status == .passed)
        #expect(codex.hostOutput == "codex-cli 0.50.0")
        #expect(
            codex.commandToRunYourself
                == "ssh devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lic \"command -v codex && codex --version\"'")
    }

    @Test func aCLIThatFailsOrHangsOnItsVersionIsAWarning() throws {
        let output = hostCheckOutput([
            "cli-opencode-path": "/home/me/.npm/bin/opencode",
            "cli-opencode-version": "env: node: No such file or directory",
            "cli-opencode-version-exit": "127",
            "cli-pi-path": "/home/me/.local/bin/pi",
            "cli-pi-version": "",
            "cli-pi-version-exit": "\(RemoteHostCheckScript.stoppedAtTimeLimitStatus)",
        ])
        let found = findings(in: output)

        let opencode = try #require(found.first { $0.id == "cli-opencode" })
        #expect(opencode.status == .warning)
        #expect(opencode.hostOutput == "env: node: No such file or directory")
        let pi = try #require(found.first { $0.id == "cli-pi" })
        #expect(pi.status == .warning)
        #expect(pi.summary.contains("\(RemoteHostCheckScript.versionTimeoutSeconds) seconds"))
    }

    @Test func aMissingCLIIsAProblemForTheTabsSessionAndAWarningForListedSessions() throws {
        let found = findings(
            in: hostCheckOutput(["cli-claude-path": "", "cli-codex-path": ""]),
            session: HostCheckSession(provider: .claude, projectPath: "/home/me/app"),
            providersWithSessions: [.codex]
        )

        #expect(found.first { $0.id == "cli-claude" }?.status == .problem)
        #expect(found.first { $0.id == "cli-codex" }?.status == .warning)
        let others = try #require(found.first { $0.id == "cli-others" })
        #expect(others.status == .note)
        #expect(!others.summary.contains("Claude Code"))
        #expect(!others.summary.contains("Codex"))
        #expect(others.summary.contains("Pi"))
    }

    @Test func aPlainTerminalsTabNeedsNoCLI() {
        let found = findings(
            in: hostCheckOutput([:]),
            session: HostCheckSession(provider: nil, projectPath: "/home/me/app")
        )
        #expect(found.map(\.id) == ["cli-others"])
    }

    @Test func yourStartCommandsProgramIsLookedUpButNotAskedForItsVersion() throws {
        let programs = RemoteHostCheckProgram.all { $0 == .claude ? "~/bin/claude-wrapper --fast" : nil }
        let claude = try #require(programs.first { $0.provider == .claude })
        #expect(claude.program == "~/bin/claude-wrapper")
        #expect(!claude.asksVersion)

        let found = findings(
            in: hostCheckOutput(["cli-claude-path": "/home/me/bin/claude-wrapper"]),
            programs: [claude]
        )

        #expect(found.first?.status == .passed)
        #expect(
            found.first?.commandToRunYourself
                == "ssh devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lic \"command -v ~/bin/claude-wrapper\"'")
    }

    @Test func aStartCommandWhoseProgramIsKnownOnlyWhenItRunsIsLeftOut() {
        let programs = RemoteHostCheckProgram.all { $0 == .claude ? "$CLAUDE_BIN" : nil }
        #expect(!programs.contains { $0.provider == .claude })
        #expect(programs.count == ConversationProvider.allCases.count - 1)
    }

    @Test func anAliasOrFunctionOfTheLoginShellIsFoundThere() throws {
        let programs = RemoteHostCheckProgram.all { _ in nil }.map { $0.located(by: [.claude: .loginShell, .pi: .loginShell]) }
        let found = findings(
            in: hostCheckOutput([
                "cli-claude-path": "",
                "cli-claude-version": "2.1.0 (Claude Code)",
                "cli-claude-version-exit": "0",
                "cli-pi-path": "",
                "cli-pi-version": "env: node: No such file or directory",
                "cli-pi-version-exit": "127",
            ]),
            programs: programs
        )

        let claude = try #require(found.first { $0.id == "cli-claude" })
        #expect(claude.status == .passed)
        #expect(claude.summary.contains("alias or function"))
        #expect(claude.hostOutput == "2.1.0 (Claude Code)")
        #expect(
            claude.commandToRunYourself
                == "ssh devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lic \"command -v claude && claude --version\"'")
        let pi = try #require(found.first { $0.id == "cli-pi" })
        #expect(pi.status == .warning)
        #expect(pi.summary.contains("alias or function"))
    }

    @Test func aCLIInAnInstallFolderSaysTabsStartItThere() throws {
        let path = "/home/me/.claude/local/claude"
        let programs = RemoteHostCheckProgram.all { _ in nil }.map { $0.located(by: [.claude: .installed(path: path)]) }
        let found = findings(
            in: hostCheckOutput([
                "cli-claude-path": path,
                "cli-claude-version": "2.1.0 (Claude Code)",
                "cli-claude-version-exit": "0",
            ]),
            programs: programs
        )

        let claude = try #require(found.first { $0.id == "cli-claude" })
        #expect(claude.status == .passed)
        #expect(claude.summary.contains(path))
        #expect(claude.summary.contains("PATH"))
        #expect(
            claude.commandToRunYourself
                == "ssh devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lic \"command -v \(path) && \(path) --version\"'")
    }

    @Test func aStartCommandsProgramKeepsItsPlaceWhereverTheExecutableIs() throws {
        let programs = RemoteHostCheckProgram.all { $0 == .claude ? "~/bin/claude-wrapper --fast" : nil }
        let claude = try #require(programs.first { $0.provider == .claude })

        #expect(claude.located(by: [.claude: .installed(path: "/home/me/.claude/local/claude")]) == claude)
    }

    private func findings(
        in output: RemoteHostCheckOutput,
        programs: [RemoteHostCheckProgram] = RemoteHostCheckProgram.all { _ in nil },
        session: HostCheckSession? = nil,
        providersWithSessions: Set<ConversationProvider> = []
    ) -> [HostCheckFinding] {
        RemoteHostCLIFindings.findings(
            in: output,
            context: hostCheckContext(programs: programs, session: session, providersWithSessions: providersWithSessions)
        )
    }
}
