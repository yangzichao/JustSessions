import Foundation
import Testing

@testable import JustSessions

struct LocalFileLinkSafetyTests {
    @Test(arguments: ["main.swift", "README.md", "build.sh", "report.pdf", "photo.png"])
    func documentsAndSourceFilesOpen(_ name: String) throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(LocalFileLinkSafety.canOpen(try makeFile(name, in: folder)))
    }

    @Test func aFolderOpens() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(LocalFileLinkSafety.canOpen(folder))
    }

    @Test func aScriptWithAnExtensionOpensEvenWhenExecutable() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(LocalFileLinkSafety.canOpen(try makeFile("deploy.sh", in: folder, executable: true)))
    }

    @Test func aMissingFileDoesNotOpen() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(!LocalFileLinkSafety.canOpen(folder.appendingPathComponent("missing.md")))
    }

    /// Terminal runs these, or the commands they hold, as they open.
    @Test(arguments: ["install.command", "install.tool", "Profile.terminal"])
    func terminalScriptsAndSettingsDoNotOpen(_ name: String) throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(!LocalFileLinkSafety.canOpen(try makeFile(name, in: folder)))
    }

    @Test func anExecutableWithoutAnExtensionDoesNotOpen() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(!LocalFileLinkSafety.canOpen(try makeFile("payload", in: folder, executable: true)))
    }

    @Test func anAppDoesNotOpen() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let app = folder.appendingPathComponent("Payload.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)

        #expect(!LocalFileLinkSafety.canOpen(app))
    }

    @Test func aJavaArchiveDoesNotOpen() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(!LocalFileLinkSafety.canOpen(try makeFile("tool.jar", in: folder)))
    }

    @Test func aWebAddressIsNoFile() {
        #expect(!LocalFileLinkSafety.canOpen(URL(string: "https://example.com")!))
    }

    private func makeFile(_ name: String, in folder: URL, executable: Bool = false) throws -> URL {
        let file = folder.appendingPathComponent(name)
        try Data("contents\n".utf8).write(to: file)
        if executable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        return file
    }
}
