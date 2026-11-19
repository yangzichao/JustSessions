import Foundation

@MainActor
final class TerminalSSHFileDropCopy {
    struct File: Sendable {
        let id = UUID()
        let url: URL
        let byteCount: Int64
        var isPastedImage = false
    }

    let id = UUID()
    let startedAt = Date()
    let cancellation = RemoteDroppedFileCopyCancellation()
    private(set) var fileCount: Int
    private(set) var hostPaths: [String] = []
    private(set) var currentFile: File?
    private var queuedFiles: [File]
    private var totalByteCount: Int64
    private var copiedByteCountOfFinishedFiles: Int64 = 0
    private var copiedByteCountOfCurrentFile: Int64 = 0
    private var pastedImageURLs: [URL]

    init(files: [File]) {
        queuedFiles = files
        fileCount = files.count
        totalByteCount = files.reduce(0) { $0 + $1.byteCount }
        pastedImageURLs = files.filter(\.isPastedImage).map(\.url)
    }

    var currentFileNumber: Int { hostPaths.count + 1 }

    var fractionCopied: Double {
        guard totalByteCount > 0 else { return 0 }
        return min(1, Double(copiedByteCountOfFinishedFiles + copiedByteCountOfCurrentFile) / Double(totalByteCount))
    }

    func add(_ files: [File]) {
        queuedFiles += files
        fileCount += files.count
        totalByteCount += files.reduce(0) { $0 + $1.byteCount }
        pastedImageURLs += files.filter(\.isPastedImage).map(\.url)
    }

    func removePastedImages() {
        pastedImageURLs.forEach(TerminalPastedImageFile.remove)
        pastedImageURLs = []
    }

    func nextFile() -> File? {
        guard !queuedFiles.isEmpty else { return nil }
        let file = queuedFiles.removeFirst()
        currentFile = file
        copiedByteCountOfCurrentFile = 0
        return file
    }

    func updateProgress(of fileID: UUID, copiedByteCount: Int64) {
        guard currentFile?.id == fileID else { return }
        copiedByteCountOfCurrentFile = copiedByteCount
    }

    func finishFile(_ file: File, hostPath: String) {
        hostPaths.append(hostPath)
        copiedByteCountOfFinishedFiles += file.byteCount
        copiedByteCountOfCurrentFile = 0
        currentFile = nil
    }
}
