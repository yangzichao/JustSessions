import Combine
import Foundation
import Testing

@testable import JustSessions

/// Files dropped on a tab on an SSH host are copied there, then their host paths typed; a local shell stands in for
/// `ssh` and the host.
@MainActor
struct TerminalSSHFileDropTests {
    @Test func copiedFilesTypeTheirHostPathsTogetherInTheOrderDropped() async throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let screenshot = try makeDroppedFile(named: "shot.png", byteCount: 2_000, in: home)
        let notes = try makeDroppedFile(named: "notes.txt", byteCount: 30, in: home)
        let fileDrop = makeFileDrop(copier: .local(home: home))
        var typedPaths: [[String]] = []
        fileDrop.typePaths = { typedPaths.append($0) }

        #expect(fileDrop.take([screenshot, notes]))

        try await expectEventually { !typedPaths.isEmpty }
        let hostPaths = try #require(typedPaths.first)
        #expect(typedPaths.count == 1)
        #expect(hostPaths.map { URL(fileURLWithPath: $0).lastPathComponent } == ["shot.png", "notes.txt"])
        #expect(try Data(contentsOf: URL(fileURLWithPath: hostPaths[0])) == Data(contentsOf: screenshot))
        #expect(fileDrop.status == nil)
        #expect(!fileDrop.isCopying)
    }

    @Test func filesDroppedWhileACopyRunsJoinIt() async throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let first = try makeDroppedFile(named: "first.png", byteCount: 10, in: home)
        let second = try makeDroppedFile(named: "second.png", byteCount: 10, in: home)
        let fileDrop = makeFileDrop(copier: .local(home: home, firstCommands: "sleep 0.3; "))
        var typedPaths: [[String]] = []
        fileDrop.typePaths = { typedPaths.append($0) }

        #expect(fileDrop.take([first]))
        #expect(fileDrop.take([second]))

        try await expectEventually { !typedPaths.isEmpty }
        #expect(typedPaths.map { $0.map { URL(fileURLWithPath: $0).lastPathComponent } } == [["first.png", "second.png"]])
    }

    @Test func aCopyThatTakesAMomentShowsItsProgressWithTheFile() async throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let fileDrop = makeFileDrop(copier: .local(home: home, firstCommands: "sleep 1.5; "))
        var typedPaths: [[String]] = []
        fileDrop.typePaths = { typedPaths.append($0) }
        // Every status shown: a full test run can keep the main thread busy past the whole copy between two checks.
        var shownStatuses: [TerminalSSHFileDropStatus?] = []
        let subscription = fileDrop.$status.sink { shownStatuses.append($0) }
        defer { subscription.cancel() }

        #expect(fileDrop.take([file]))

        try await expectEventually { !typedPaths.isEmpty }
        #expect(
            shownStatuses.contains { status in
                guard case .copying(let fileName, let fileNumber, let fileCount, _) = status else { return false }
                return fileName == "shot.png" && fileNumber == 1 && fileCount == 1
            })
        #expect(fileDrop.status == nil)
    }

    @Test func aDropWithAFolderIsRefusedAndSaysWhy() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let folder = home.appendingPathComponent("Screenshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileDrop = makeFileDrop(copier: .local(home: home))

        #expect(!fileDrop.take([file, folder]))

        #expect(!fileDrop.isCopying)
        #expect(fileDrop.status == .failed(explanation: "Folders aren't copied to devbox. Drop the files in Screenshots instead."))
    }

    @Test func aFailedCopyTypesNothingAndSaysWhy() async throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let fileDrop = makeFileDrop(
            copier: .replacingSSH(
                with: "cat > /dev/null; echo 'ssh: connect to host devbox port 22: Connection refused' >&2; exit 255"
            ))
        var typedPaths: [[String]] = []
        fileDrop.typePaths = { typedPaths.append($0) }

        #expect(fileDrop.take([file]))

        try await expectEventually { fileDrop.status != nil }
        #expect(fileDrop.status == .failed(explanation: SSHConnectionProblem.refused.explanation(host: "devbox")))
        #expect(typedPaths.isEmpty)
        #expect(!fileDrop.isCopying)
    }

    @Test func theNextDropClearsAnEarlierFailure() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let fileDrop = makeFileDrop(copier: .local(home: home, firstCommands: "sleep 0.3; "))
        _ = fileDrop.take([home])
        #expect(fileDrop.status != nil)

        #expect(fileDrop.take([file]))

        #expect(fileDrop.status == nil)
        fileDrop.cancel()
    }

    @Test func cancellingTypesNothing() async throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let fileDrop = makeFileDrop(copier: .local(home: home, firstCommands: "sleep 1; "))
        var typedPaths: [[String]] = []
        fileDrop.typePaths = { typedPaths.append($0) }
        #expect(fileDrop.take([file]))

        fileDrop.cancel()

        #expect(!fileDrop.isCopying)
        #expect(fileDrop.status == nil)
        // Longer than the copy would have taken.
        try await Task.sleep(for: .seconds(2))
        #expect(typedPaths.isEmpty)
        #expect(fileDrop.status == nil)
    }

    private func makeFileDrop(copier: RemoteDroppedFileCopier) -> TerminalSSHFileDrop {
        let fileDrop = TerminalSSHFileDrop(host: "devbox")
        fileDrop.copier = copier
        fileDrop.connectionSharing = { _ in nil }
        return fileDrop
    }
}
