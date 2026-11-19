import Foundation
import Testing

@testable import JustSessions

struct TerminalLinkLocalItemTests {
    @Test func aFileIsAFileAndAFolderAFolder() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("plan.md")
        try Data("# Plan\n".utf8).write(to: file)

        #expect(TerminalLinkLocalItem.kind(of: file) == .file)
        #expect(TerminalLinkLocalItem.kind(of: folder) == .folder)
    }

    /// Opening an app's folder would start the app, so it isn't a folder to open in the Finder.
    @Test func anAppIsAFile() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let app = folder.appendingPathComponent("Payload.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)

        #expect(TerminalLinkLocalItem.kind(of: app) == .file)
    }

    @Test func nothingIsThereForAMissingFile() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(TerminalLinkLocalItem.kind(of: folder.appendingPathComponent("missing.md")) == nil)
    }

    @Test func theLineAndColumnFollowThePathAsVSCodeTakesThem() {
        let url = URL(fileURLWithPath: "/Users/me/paper/main.swift")

        #expect(TerminalLinkLocalItem(url: url, kind: .file).pathWithLineAndColumn == "/Users/me/paper/main.swift")
        #expect(TerminalLinkLocalItem(url: url, kind: .file, lineNumber: 42).pathWithLineAndColumn == "/Users/me/paper/main.swift:42")
        #expect(
            TerminalLinkLocalItem(url: url, kind: .file, lineNumber: 42, columnNumber: 7).pathWithLineAndColumn
                == "/Users/me/paper/main.swift:42:7")
    }
}
