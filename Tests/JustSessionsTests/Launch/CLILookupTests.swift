import Foundation
import Testing
@testable import JustSessions

struct CLILookupTests {
    @Test func standardDirectoriesPutInheritedThenLoginShellThenFallbacks() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        for version in ["v9.11.2", "v22.3.0", "v18.20.1"] {
            try FileManager.default.createDirectory(
                at: home.appendingPathComponent(".nvm/versions/node/\(version)/bin"),
                withIntermediateDirectories: true
            )
        }

        let directories = CLISearchDirectories.standard(
            inheritedEnvironment: ["PATH": "/usr/bin:/bin"],
            loginShellDirectories: ["/from/login/shell", "/usr/bin"],
            homeDirectory: home.path
        )

        #expect(Array(directories.prefix(4)) == ["/usr/bin", "/bin", "/from/login/shell", "\(home.path)/.local/bin"])
        #expect(directories.filter { $0 == "/usr/bin" }.count == 1)
        #expect(Array(directories.suffix(3)) == [
            "\(home.path)/.nvm/versions/node/v22.3.0/bin",
            "\(home.path)/.nvm/versions/node/v18.20.1/bin",
            "\(home.path)/.nvm/versions/node/v9.11.2/bin",
        ])
    }

    @Test func findsCLIThatOnlyTheLoginShellKnowsAbout() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nvmBinDirectory = root.appendingPathComponent("nvm/bin")
        let projectDirectory = root.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: nvmBinDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let claude = try writeExecutableScript("#!/bin/sh\nexit 0\n", to: nvmBinDirectory.appendingPathComponent("claude"))
        let searchDirectories = CLISearchDirectories.standard(
            inheritedEnvironment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
            loginShellDirectories: [nvmBinDirectory.path],
            homeDirectory: root.path
        )
        let resolver = NativeCLICommandResolver(
            searchDirectories: searchDirectories,
            inheritedEnvironment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        )

        let command = try resolver.resolveNewSession(provider: .claude, projectPath: projectDirectory.path)

        #expect(command.executablePath == claude.path)
        #expect(command.environment.contains { $0.hasPrefix("PATH=") && $0.contains(nvmBinDirectory.path) })
    }

    @Test func findsToolboxCLIEvenWhenLoginShellPathIsUnavailable() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let toolboxBinDirectory = home.appendingPathComponent(".toolbox/bin")
        try FileManager.default.createDirectory(at: toolboxBinDirectory, withIntermediateDirectories: true)
        let claude = try writeExecutableScript("#!/bin/sh\nexit 0\n", to: toolboxBinDirectory.appendingPathComponent("claude"))
        let searchDirectories = CLISearchDirectories.standard(
            inheritedEnvironment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
            loginShellDirectories: [],
            homeDirectory: home.path
        )

        let resolver = NativeCLICommandResolver(searchDirectories: searchDirectories)

        #expect(resolver.executablePath(named: "claude") == claude.path)
    }
}
