import Foundation
import Testing

@testable import JustSessions

struct RemoteHostCheckFindingsTests {
    @Test func aScriptTheLoginShellNeverRanStopsAfterRsync() {
        let findings = RemoteHostCheckFindings.findings(
            in: hostCheckOutput(["rsync-path": "/usr/bin/rsync", "rsync-version": "rsync  version 3.2.7"]),
            context: hostCheckContext()
        )

        #expect(findings.map(\.id) == [.rsync, .loginShell])
        #expect(findings.map(\.status) == [.passed, .problem])
        #expect(findings[1].commandToRunYourself == "ssh -t devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lic \"echo Startup finished\"'")
    }

    @Test func listsTheFindingsInTheOrderTheAppDependsOnThem() {
        let findings = RemoteHostCheckFindings.findings(
            in: hostCheckOutput([
                "rsync-path": "/usr/bin/rsync",
                "shell": "/bin/bash",
                "os": "Ubuntu 24.04.3 LTS",
                "system": "Linux 6.8.0-85-generic aarch64",
                "path": "/usr/local/bin:/usr/bin:/bin",
                "tmux-path": "",
                "folder": "drwxr-xr-x 2 me me 4096 Oct 13 10:00 /home/me/app",
                "folder-exit": "0",
            ]),
            context: hostCheckContext(session: HostCheckSession(provider: nil, projectPath: "/home/me/app"))
        )

        #expect(findings.map(\.id) == [.system, .rsync, .folder, .tmux, .otherCLIs])
        #expect(findings[0].summary == "Ubuntu 24.04.3 LTS · Linux 6.8.0-85-generic aarch64")
        #expect(findings[0].hostOutput == "SHELL=/bin/bash\nPATH=/usr/local/bin:/usr/bin:/bin")
        #expect(findings[2].status == .passed)
        #expect(findings[2].commandToRunYourself == "ssh devbox 'ls -ld /home/me/app'")
    }

    @Test func noRsyncIsAProblem() {
        let finding = RemoteHostCheckFindings.rsyncFinding(in: hostCheckOutput(["rsync-path": ""]), host: "devbox")
        #expect(finding.status == .problem)
        #expect(finding.commandToRunYourself == "ssh devbox 'command -v rsync && rsync --version'")
    }

    @Test func aMissingFolderIsAProblem() {
        let finding = RemoteHostCheckFindings.folderFinding(
            in: hostCheckOutput([
                "folder": "ls: cannot access '/home/me/app': No such file or directory",
                "folder-exit": "1",
            ]),
            projectPath: "/home/me/app",
            host: "devbox"
        )
        #expect(finding.status == .problem)
        #expect(finding.hostOutput == "ls: cannot access '/home/me/app': No such file or directory")
    }

    @Test func aFolderTheCheckCouldNotQuoteIsANote() {
        let finding = RemoteHostCheckFindings.folderFinding(
            in: hostCheckOutput([:]),
            projectPath: "/home/me/it's",
            host: "devbox"
        )
        #expect(finding.status == .note)
        #expect(finding.commandToRunYourself == nil)
    }

    @Test func python3IsCheckedOnlyForToolsCopiedThroughIt() {
        let withoutThoseTools = hostCheckOutput(["python3-path": "", "cli-codex-path": "/usr/bin/codex"])
        #expect(RemoteHostCheckFindings.pythonFinding(in: withoutThoseTools, context: hostCheckContext()) == nil)

        let openCodeWithoutPython = hostCheckOutput(["python3-path": "", "cli-opencode-path": "/usr/bin/opencode"])
        #expect(RemoteHostCheckFindings.pythonFinding(in: openCodeWithoutPython, context: hostCheckContext())?.status == .problem)

        let sessionsWithBrokenSQLite = hostCheckOutput([
            "python3-path": "/usr/bin/python3",
            "python3-sqlite3": "ModuleNotFoundError: No module named '_sqlite3'",
            "python3-sqlite3-exit": "1",
        ])
        let finding = RemoteHostCheckFindings.pythonFinding(
            in: sessionsWithBrokenSQLite,
            context: hostCheckContext(providersWithSessions: [.antigravity])
        )
        #expect(finding?.status == .problem)
        #expect(finding?.hostOutput == "ModuleNotFoundError: No module named '_sqlite3'")
    }
}
