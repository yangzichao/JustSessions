import Foundation
import Testing

@testable import JustSessions

struct RemoteDroppedFileCopyScriptTests {
    @Test func theLastFolderLineNamesTheFolderWhateverAProfilePrintsFirst() {
        let output = """
            Welcome to devbox
            __JUSTSESSIONS_DROPPED_FILE_FOLDER__/home/me/.cache/justsessions/dropped-files/old
            __JUSTSESSIONS_DROPPED_FILE_FOLDER__/home/me/.cache/justsessions/dropped-files/aB3dE9xQ

            """

        #expect(RemoteDroppedFileCopyScript.folder(inOutput: output) == "/home/me/.cache/justsessions/dropped-files/aB3dE9xQ")
    }

    @Test func outputWithoutAnAbsoluteFolderNamesNone() {
        #expect(RemoteDroppedFileCopyScript.folder(inOutput: "Welcome to devbox\n") == nil)
        #expect(RemoteDroppedFileCopyScript.folder(inOutput: "__JUSTSESSIONS_DROPPED_FILE_FOLDER__relative/path\n") == nil)
    }

    @Test(arguments: ["/bin/sh", "/bin/bash", "/bin/zsh", "/bin/dash"])
    func theFileArrivesUnderItsOwnNameInAFolderOnlyItsOwnerCanOpen(loginShell: String) throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let name = "it's a $HOME `x` (1) & \"截图\" \u{202F}.png"
        let source = try makeDroppedFile(named: "source", byteCount: 70_000, in: home)

        let result = try Self.run(fileName: name, byteCount: 70_000, from: source, home: home, loginShell: loginShell)

        #expect(result.exitStatus == 0, "\(result.output)")
        let folder = try #require(RemoteDroppedFileCopyScript.folder(inOutput: result.output))
        #expect(URL(fileURLWithPath: folder).deletingLastPathComponent().path == Self.droppedFilesFolder(in: home).path)
        #expect(try Data(contentsOf: URL(fileURLWithPath: folder).appendingPathComponent(name)) == Data(contentsOf: source))
        let permissions = try FileManager.default.attributesOfItem(atPath: folder)[.posixPermissions] as? Int
        #expect(permissions == 0o700)
    }

    @Test func aCopyThatEndsShortLeavesNothing() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let source = try makeDroppedFile(named: "source", byteCount: 1_000, in: home)

        let result = try Self.run(fileName: "shot.png", byteCount: 1_001, from: source, home: home)

        #expect(result.exitStatus == RemoteDroppedFileCopyScript.ExitStatus.incomplete)
        #expect(try FileManager.default.contentsOfDirectory(atPath: Self.droppedFilesFolder(in: home).path).isEmpty)
    }

    @Test func copiesMoreThanAWeekOldAreRemovedByTheNextCopy() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let droppedFiles = Self.droppedFilesFolder(in: home)
        let oldCopy = droppedFiles.appendingPathComponent("oldcopy")
        let recentCopy = droppedFiles.appendingPathComponent("recentcopy")
        for (copy, age) in [(oldCopy, 8.0), (recentCopy, 6.0)] {
            try FileManager.default.createDirectory(at: copy, withIntermediateDirectories: true)
            _ = try makeDroppedFile(named: "shot.png", byteCount: 10, in: copy)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -age * 86_400)], ofItemAtPath: copy.path)
        }
        let source = try makeDroppedFile(named: "source", byteCount: 10, in: home)

        let result = try Self.run(fileName: "new.png", byteCount: 10, from: source, home: home)

        #expect(result.exitStatus == 0)
        #expect(!FileManager.default.fileExists(atPath: oldCopy.path))
        #expect(FileManager.default.fileExists(atPath: recentCopy.appendingPathComponent("shot.png").path))
    }

    @Test func aHomeFolderWithNoRoomForTheFolderFailsWithItsOwnStatus() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        try Data().write(to: home.appendingPathComponent(".cache"))
        let source = try makeDroppedFile(named: "source", byteCount: 10, in: home)

        let result = try Self.run(fileName: "shot.png", byteCount: 10, from: source, home: home)

        #expect(result.exitStatus == RemoteDroppedFileCopyScript.ExitStatus.couldNotMakeFolder)
    }

    private static func droppedFilesFolder(in home: URL) -> URL {
        home.appendingPathComponent(RemoteDroppedFileCopyScript.droppedFilesFolder)
    }

    private static func run(
        fileName: String,
        byteCount: Int64,
        from source: URL,
        home: URL,
        loginShell: String = "/bin/sh"
    ) throws -> (exitStatus: Int32, output: String) {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: loginShell)
        process.arguments = ["-c", RemoteDroppedFileCopyScript.command(fileName: fileName, byteCount: byteCount)]
        process.environment = ["HOME": home.path, "PATH": "/usr/bin:/bin"]
        process.currentDirectoryURL = home
        process.standardInput = try FileHandle(forReadingFrom: source)
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let printed = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: printed, as: UTF8.self))
    }
}
