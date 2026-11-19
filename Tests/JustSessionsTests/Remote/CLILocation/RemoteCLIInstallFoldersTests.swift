import Foundation
import Testing

@testable import JustSessions

struct RemoteCLIInstallFoldersTests {
    @Test func aFolderOutsideNvmComesFirstThenTheNewestNodeVersion() {
        let nvm = "/home/me/.nvm/versions/node"
        #expect(
            RemoteCLIInstallFolders.preferredPath(among: [
                "/home/me/.local/bin/claude", "/home/me/.claude/local/claude", "\(nvm)/v22.3.0/bin/claude",
            ]) == "/home/me/.local/bin/claude")
        #expect(
            RemoteCLIInstallFolders.preferredPath(among: [
                "\(nvm)/v18.20.1/bin/codex", "\(nvm)/v22.3.0/bin/codex", "\(nvm)/v9.11.2/bin/codex",
            ]) == "\(nvm)/v22.3.0/bin/codex")
        #expect(RemoteCLIInstallFolders.preferredPath(among: []) == nil)
    }

    @Test func theSearchFindsExecutablesInTheInstallFoldersOfTheHostsHome() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        for path in [
            ".claude/local/claude", ".opencode/bin/opencode", ".nvm/versions/node/v9.11.2/bin/codex",
            ".nvm/versions/node/v22.3.0/bin/codex",
        ] {
            try writeExecutable(at: home.appendingPathComponent(path))
        }
        // Neither a folder nor a file that can't run is a CLI.
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".local/bin/pi"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".bun/bin"), withIntermediateDirectories: true)
        try "".write(to: home.appendingPathComponent(".bun/bin/agy"), atomically: true, encoding: .utf8)

        let script = RemoteCLIInstallFolders.searchScript(executableNames: ["claude", "codex", "opencode", "pi", "agy"])
        let output = try #require(
            BoundedProcessRunner.output(
                ofExecutable: "/bin/sh",
                arguments: ["-c", script],
                environment: ["HOME": home.path, "PATH": "/usr/bin:/bin"],
                timeout: 10
            ))

        // Folders outside the home folder, such as `/opt/homebrew/bin`, may have this Mac's own CLIs.
        let foundInHome = output.split(separator: "\n").map(String.init).filter { $0.contains(home.path) }
        #expect(
            foundInHome == [
                "claude \(home.path)/.claude/local/claude",
                "codex \(home.path)/.nvm/versions/node/v22.3.0/bin/codex",
                "codex \(home.path)/.nvm/versions/node/v9.11.2/bin/codex",
                "opencode \(home.path)/.opencode/bin/opencode",
            ])
        #expect(!script.contains("'"))
        #expect(!script.contains("\\"))
    }

    private func writeExecutable(at file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\n", to: file)
    }
}
