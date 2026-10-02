import Foundation
@testable import JustSessions

struct BundledTmuxFixture {
    let root: URL
    let runtime: URL
    let installedDirectory: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("bundled-tmux-\(UUID())")
        runtime = root.appendingPathComponent("App with spaces.app/Contents/Resources/Tmux")
        installedDirectory = root.appendingPathComponent("installed")
        for directory in [runtime.appendingPathComponent("bin"), runtime.appendingPathComponent("share/terminfo"), installedDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    var resolver: NativeCLICommandResolver {
        NativeCLICommandResolver(searchDirectories: [installedDirectory.path], inheritedEnvironment: [:], bundledTmuxDirectory: runtime)
    }

    @discardableResult
    func writeTmux(in directory: URL, version: String, hasRunningSessions: Bool = false) throws -> URL {
        try writeExecutableScript("""
            #!/bin/sh
            if [ "$1" = '-V' ]; then echo 'tmux \(version)'; exit 0; fi
            if [ "$3" = 'list-sessions' ]; then
                \(hasRunningSessions ? "echo 'justsessions-claude-running'; exit 0" : "exit 1")
            fi
            exit 1
            """, to: directory.appendingPathComponent("tmux"))
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }
}
