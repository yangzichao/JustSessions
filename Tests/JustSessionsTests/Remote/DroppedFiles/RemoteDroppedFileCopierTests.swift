import Foundation
import Testing

@testable import JustSessions

struct RemoteDroppedFileCopierTests {
    @Test func theFileArrivesAndItsPathOnTheHostIsReturned() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot 1.png", byteCount: 300_000, in: home)
        let progress = LockedValue<[Int64]>([])

        let hostPath = try RemoteDroppedFileCopier.local(home: home).copy(
            file,
            to: "devbox",
            connectionOptions: [],
            cancellation: RemoteDroppedFileCopyCancellation()
        ) { copiedByteCount in progress.update { $0.append(copiedByteCount) } }

        #expect(hostPath.hasPrefix(home.path + "/" + RemoteDroppedFileCopyScript.droppedFilesFolder + "/"))
        #expect(hostPath.hasSuffix("/shot 1.png"))
        #expect(try Data(contentsOf: URL(fileURLWithPath: hostPath)) == Data(contentsOf: file))
        #expect(progress.value.last == 300_000)
    }

    @Test func aSymbolicLinkSendsTheFileItLeadsTo() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "original.png", byteCount: 5_000, in: home)
        let link = home.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)

        let hostPath = try RemoteDroppedFileCopier.local(home: home).copy(
            link,
            to: "devbox",
            connectionOptions: [],
            cancellation: RemoteDroppedFileCopyCancellation()
        ) { _ in }

        #expect(hostPath.hasSuffix("/link.png"))
        #expect(try Data(contentsOf: URL(fileURLWithPath: hostPath)) == Data(contentsOf: file))
    }

    @Test func sshConnectsAsTheAppsBackgroundCommandsDo() {
        let launch = RemoteDroppedFileCopier().processLaunch("devbox", "HOST_COMMAND", ["-o", "ControlPath=/tmp/shared"])

        #expect(launch.executablePath == "/usr/bin/ssh")
        #expect(
            launch.arguments == ["-T"] + RemoteHostCommandRunner.nonInteractiveSSHOptions
                + ["-o", "ControlPath=/tmp/shared", "devbox", "HOST_COMMAND"])
    }

    @Test func aConnectionThatFailsSaysWhy() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let copier = RemoteDroppedFileCopier.replacingSSH(
            with: "cat > /dev/null; echo 'ssh: connect to host devbox port 22: Connection refused' >&2; exit 255"
        )

        #expect(throws: RemoteDroppedFileCopyError.sshFailed(host: "devbox", problem: .refused)) {
            try copier.copy(file, to: "devbox", connectionOptions: [], cancellation: RemoteDroppedFileCopyCancellation()) { _ in }
        }
    }

    @Test func aConnectionThatEndsMidCopyWasLost() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 300_000, in: home)
        let copier = RemoteDroppedFileCopier.replacingSSH(with: "head -c 5 > /dev/null; exit 255")

        #expect(throws: RemoteDroppedFileCopyError.sshFailed(host: "devbox", problem: .connectionLost)) {
            try copier.copy(file, to: "devbox", connectionOptions: [], cancellation: RemoteDroppedFileCopyCancellation()) { _ in }
        }
    }

    @Test func aCopyTheHostFindsShortIsReportedAsIncomplete() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let copier = RemoteDroppedFileCopier.replacingSSH(
            with: "cat > /dev/null; exit \(RemoteDroppedFileCopyScript.ExitStatus.incomplete)"
        )

        #expect(throws: RemoteDroppedFileCopyError.incomplete(host: "devbox", fileName: "shot.png")) {
            try copier.copy(file, to: "devbox", connectionOptions: [], cancellation: RemoteDroppedFileCopyCancellation()) { _ in }
        }
    }

    @Test func aHostThatSaysNothingOfTheFolderFails() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let copier = RemoteDroppedFileCopier.replacingSSH(with: "cat > /dev/null; echo 'Welcome to devbox'")

        #expect(throws: RemoteDroppedFileCopyError.failed(host: "devbox", output: "Welcome to devbox")) {
            try copier.copy(file, to: "devbox", connectionOptions: [], cancellation: RemoteDroppedFileCopyCancellation()) { _ in }
        }
    }

    @Test func aFileThatCantBeReadIsNamed() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        for unreadable in [home.appendingPathComponent("missing.png"), home] {
            #expect(throws: RemoteDroppedFileCopyError.couldNotRead(fileName: unreadable.lastPathComponent)) {
                try RemoteDroppedFileCopier.local(home: home).copy(
                    unreadable,
                    to: "devbox",
                    connectionOptions: [],
                    cancellation: RemoteDroppedFileCopyCancellation()
                ) { _ in }
            }
        }
    }

    @Test func cancellingStopsTheCopy() async throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = try makeDroppedFile(named: "shot.png", byteCount: 10, in: home)
        let copier = RemoteDroppedFileCopier.replacingSSH(with: "exec sleep 600")
        let cancellation = RemoteDroppedFileCopyCancellation()

        let (outcome, copyDuration) = await withCheckedContinuation {
            (continuation: CheckedContinuation<(Result<String, any Error>, Duration), Never>) in
            DispatchQueue.global().async {
                let started = ContinuousClock.now
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { cancellation.cancel() }
                let outcome = Result {
                    try copier.copy(file, to: "devbox", connectionOptions: [], cancellation: cancellation) { _ in }
                }
                continuation.resume(returning: (outcome, ContinuousClock.now - started))
            }
        }

        #expect(throws: CancellationError.self) { try outcome.get() }
        #expect(copyDuration < .seconds(120))
    }
}
