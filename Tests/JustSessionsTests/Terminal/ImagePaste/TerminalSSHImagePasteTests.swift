import AppKit
import Foundation
import Testing

@testable import JustSessions

@MainActor
struct TerminalSSHImagePasteTests {
    @Test func aPastedImageReachesTheHostAndLeavesNothingOnThisMac() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let png = makePNGData()
        let fileDrop = try makeFileDrop(in: folder, copier: .local(home: folder.appendingPathComponent("host-home")))
        var typedPaths: [[String]] = []
        fileDrop.typePaths = { typedPaths.append($0) }

        fileDrop.take(try image(png))

        try await expectEventually { !typedPaths.isEmpty }
        let hostPaths = try #require(typedPaths.first)
        #expect(hostPaths.map { URL(fileURLWithPath: $0).lastPathComponent } == ["pasted-image.png"])
        #expect(try Data(contentsOf: URL(fileURLWithPath: hostPaths[0])) == png)
        #expect(try savedImages(in: fileDrop).isEmpty)
        #expect(fileDrop.status == nil)
    }

    @Test func imagesPastedWhileADropCopiesJoinItInTurn() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let hostHome = folder.appendingPathComponent("host-home")
        let screenshot = try makeDroppedFile(named: "shot.png", byteCount: 100, in: folder)
        let fileDrop = try makeFileDrop(in: folder, copier: .local(home: hostHome, firstCommands: "sleep 0.3; "))
        var typedPaths: [[String]] = []
        fileDrop.typePaths = { typedPaths.append($0) }
        let first = makePNGData(width: 3)
        let second = makePNGData(width: 5)

        #expect(fileDrop.take([screenshot]))
        fileDrop.take(try image(first))
        fileDrop.take(try image(second))

        try await expectEventually(timeout: .seconds(300)) { !typedPaths.isEmpty }
        let hostPaths = try #require(typedPaths.first)
        #expect(typedPaths.count == 1)
        #expect(hostPaths.map { URL(fileURLWithPath: $0).lastPathComponent } == ["shot.png", "pasted-image.png", "pasted-image.png"])
        #expect(try Data(contentsOf: URL(fileURLWithPath: hostPaths[1])) == first)
        #expect(try Data(contentsOf: URL(fileURLWithPath: hostPaths[2])) == second)
        #expect(try savedImages(in: fileDrop).isEmpty)
        #expect(FileManager.default.fileExists(atPath: screenshot.path))
    }

    @Test func cancellingRemovesTheSavedImage() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let hostHome = folder.appendingPathComponent("host-home")
        let fileDrop = try makeFileDrop(in: folder, copier: .local(home: hostHome, firstCommands: "sleep 1; "))
        var typedPaths: [[String]] = []
        fileDrop.typePaths = { typedPaths.append($0) }
        fileDrop.take(try image(makePNGData()))
        #expect(try savedImages(in: fileDrop).count == 1)

        fileDrop.cancel()

        try await expectEventually { (try? savedImages(in: fileDrop).isEmpty) == true }
        #expect(typedPaths.isEmpty)
    }

    @Test func aFailedCopyRemovesTheSavedImageAndSaysWhy() async throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let fileDrop = try makeFileDrop(
            in: folder,
            copier: .replacingSSH(
                with: "cat > /dev/null; echo 'ssh: connect to host devbox port 22: Connection refused' >&2; exit 255"
            ))

        fileDrop.take(try image(makePNGData()))

        try await expectEventually { fileDrop.status != nil }
        #expect(fileDrop.status == .failed(explanation: SSHConnectionProblem.refused.explanation(host: "devbox")))
        #expect(try savedImages(in: fileDrop).isEmpty)
    }

    @Test func anImageThatCanNotBeSavedSaysWhy() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let fileDrop = try makeFileDrop(in: folder, copier: .local(home: folder))
        fileDrop.pastedImagesFolder = try makeDroppedFile(named: "not-a-folder", byteCount: 1, in: folder)

        fileDrop.take(try image(makePNGData()))

        #expect(!fileDrop.isCopying)
        #expect(fileDrop.status == .failed(explanation: "The pasted image couldn't be saved on this Mac to copy it to devbox."))
    }

    private func makeFileDrop(in folder: URL, copier: RemoteDroppedFileCopier) throws -> TerminalSSHFileDrop {
        let fileDrop = TerminalSSHFileDrop(host: "devbox")
        fileDrop.copier = copier
        fileDrop.connectionSharing = { _ in nil }
        fileDrop.pastedImagesFolder = folder.appendingPathComponent("pasted images")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("host-home"), withIntermediateDirectories: true)
        return fileDrop
    }

    private func image(_ png: Data) throws -> TerminalClipboardImage {
        let pasteboard = NSPasteboard.holding([.png: png])
        defer { pasteboard.releaseGlobally() }
        return try #require(TerminalClipboardImage(pasteboard: pasteboard))
    }

    private func savedImages(in fileDrop: TerminalSSHFileDrop) throws -> [String] {
        guard FileManager.default.fileExists(atPath: fileDrop.pastedImagesFolder.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: fileDrop.pastedImagesFolder.path)
    }
}
