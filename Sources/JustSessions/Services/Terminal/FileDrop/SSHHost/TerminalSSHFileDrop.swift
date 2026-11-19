import Foundation

@MainActor
final class TerminalSSHFileDrop: ObservableObject {
    static let quietCopyDuration: TimeInterval = 0.5

    @Published private(set) var status: TerminalSSHFileDropStatus?
    let host: String
    var typePaths: ([String]) -> Void = { _ in }

    var copier = RemoteDroppedFileCopier()
    var pastedImagesFolder = TerminalPastedImageFile.defaultParentFolder
    var connectionSharing: @Sendable (_ host: String) -> SSHConnectionSharing? = { host in
        SSHConnectionSharing.startRefresh(to: host)
    }
    private var copy: TerminalSSHFileDropCopy?

    init(host: String) {
        self.host = host
    }

    var isCopying: Bool { copy != nil }

    func take(_ fileURLs: [URL]) -> Bool {
        guard !fileURLs.isEmpty else { return false }
        if let folderURL = fileURLs.first(where: Self.isFolder) {
            if copy == nil {
                status = .failed(
                    explanation: "Folders aren't copied to \(host). Drop the files in \(folderURL.lastPathComponent) instead."
                )
            }
            return false
        }
        startOrJoinCopy(of: fileURLs.map { TerminalSSHFileDropCopy.File(url: $0, byteCount: Self.byteCount(of: $0)) })
        return true
    }

    func take(_ image: TerminalClipboardImage) {
        let fileURL: URL
        do {
            fileURL = try TerminalPastedImageFile.write(image, in: pastedImagesFolder)
        } catch {
            if copy == nil {
                status = .failed(explanation: "The pasted image couldn't be saved on this Mac to copy it to \(host).")
            }
            return
        }
        let byteCount = Int64(image.data.count)
        startOrJoinCopy(of: [TerminalSSHFileDropCopy.File(url: fileURL, byteCount: byteCount, isPastedImage: true)])
    }

    func cancel() {
        guard let copy else { return }
        self.copy = nil
        copy.cancellation.cancel()
        status = nil
    }

    func dismissFailure() {
        guard case .failed = status else { return }
        status = nil
    }

    private func startOrJoinCopy(of files: [TerminalSSHFileDropCopy.File]) {
        if let copy {
            copy.add(files)
        } else {
            status = nil
            let copy = TerminalSSHFileDropCopy(files: files)
            self.copy = copy
            Task { await run(copy) }
        }
    }

    private func run(_ copy: TerminalSSHFileDropCopy) async {
        defer { copy.removePastedImages() }
        let host = self.host
        let connectionSharing = self.connectionSharing
        let sharing = await Task.detached(priority: .userInitiated) { connectionSharing(host) }.value
        defer { Task.detached(priority: .utility) { sharing?.finish() } }
        while self.copy === copy, let file = copy.nextFile() {
            do {
                copy.finishFile(file, hostPath: try await copyToHost(file, of: copy, connectionOptions: sharing?.options ?? []))
            } catch {
                guard self.copy === copy else { return }
                self.copy = nil
                status = .failed(explanation: error.localizedDescription)
                return
            }
        }
        guard self.copy === copy else { return }
        self.copy = nil
        status = nil
        typePaths(copy.hostPaths)
    }

    /// The copy blocks until `ssh` exits, so it waits on a dispatch queue instead of holding one of Swift's few task
    /// threads for as long as a large file takes.
    private func copyToHost(
        _ file: TerminalSSHFileDropCopy.File,
        of copy: TerminalSSHFileDropCopy,
        connectionOptions: [String]
    ) async throws -> String {
        let host = self.host
        let copier = self.copier
        let cancellation = copy.cancellation
        let copyID = copy.id
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let hostPath = try copier.copy(
                        file.url,
                        to: host,
                        connectionOptions: connectionOptions,
                        cancellation: cancellation
                    ) { copiedByteCount in
                        DispatchQueue.main.async {
                            MainActor.assumeIsolated {
                                self?.showProgress(of: copyID, fileID: file.id, copiedByteCount: copiedByteCount)
                            }
                        }
                    }
                    continuation.resume(returning: hostPath)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func showProgress(of copyID: UUID, fileID: UUID, copiedByteCount: Int64) {
        guard let copy, copy.id == copyID else { return }
        copy.updateProgress(of: fileID, copiedByteCount: copiedByteCount)
        guard Date().timeIntervalSince(copy.startedAt) >= Self.quietCopyDuration,
            let fileName = copy.currentFile?.url.lastPathComponent
        else { return }
        status = .copying(
            fileName: fileName,
            fileNumber: copy.currentFileNumber,
            fileCount: copy.fileCount,
            fractionCopied: copy.fractionCopied
        )
    }

    /// A symbolic link counts as what it leads to.
    private static func isFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func byteCount(of url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
