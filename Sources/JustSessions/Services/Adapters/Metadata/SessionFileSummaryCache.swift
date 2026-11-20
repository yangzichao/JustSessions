import Foundation

final class SessionFileSummaryCache<Summary: Sendable & Codable>: @unchecked Sendable {
    private struct Fingerprint: Equatable, Codable {
        let modificationDate: Date
        let size: Int
        let fileNumber: UInt64

        init?(file: URL) {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                let modificationDate = values.contentModificationDate,
                let size = values.fileSize,
                let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                let fileNumber = attributes[.systemFileNumber] as? NSNumber
            else { return nil }
            self.modificationDate = modificationDate
            self.size = size
            self.fileNumber = fileNumber.uint64Value
        }
    }

    private struct Entry: Codable {
        let fingerprint: Fingerprint
        let summary: Summary?
    }

    private struct Snapshot: Codable {
        let version: Int
        let entries: [String: Entry]
    }

    private static var snapshotLayoutVersion: Int { 1 }
    private static var maximumSnapshotByteCount: Int { 64 << 20 }

    private let lock = NSLock()
    private var entriesByPath: [String: Entry] = [:]
    private let persistenceFile: URL?
    private let persistsTemporaryFiles: Bool
    private var hasLoadedSnapshot = false
    private var needsSaving = false

    init(persistenceFile: URL? = nil, persistsTemporaryFiles: Bool = false) {
        self.persistenceFile = persistenceFile
        self.persistsTemporaryFiles = persistsTemporaryFiles
    }

    private func loadSnapshotIfNeeded() {
        guard !hasLoadedSnapshot else { return }
        hasLoadedSnapshot = true
        guard let persistenceFile,
            let size = try? persistenceFile.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size <= Self.maximumSnapshotByteCount,
            let data = try? Data(contentsOf: persistenceFile),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data), snapshot.version == Self.snapshotLayoutVersion
        else { return }
        entriesByPath = snapshot.entries
    }

    func summary(of file: URL, read: (URL) -> Summary?) -> Summary? {
        summary(ofGrowingFile: file) { file, _ in read(file) }
    }

    func summary(ofGrowingFile file: URL, read: (URL, Summary?) -> Summary?) -> Summary? {
        guard let fingerprintBeforeReading = Fingerprint(file: file) else { return read(file, nil) }
        let path = file.path
        let entry = lock.withLock {
            loadSnapshotIfNeeded()
            return entriesByPath[path]
        }
        if let entry, entry.fingerprint == fingerprintBeforeReading { return entry.summary }
        let summary = read(file, entry?.summary)
        lock.withLock {
            entriesByPath[path] = Entry(fingerprint: fingerprintBeforeReading, summary: summary)
            needsSaving = true
        }
        return summary
    }

    func forgetFiles(in directory: URL, except foundFiles: [URL]) {
        let directoryPrefix = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
        let foundPaths = Set(foundFiles.map(\.path))
        lock.withLock {
            loadSnapshotIfNeeded()
            let previousCount = entriesByPath.count
            entriesByPath = entriesByPath.filter { path, _ in
                !path.hasPrefix(directoryPrefix) || foundPaths.contains(path)
            }
            needsSaving = needsSaving || entriesByPath.count != previousCount
            saveSnapshotIfNeeded()
        }
    }

    private func saveSnapshotIfNeeded() {
        guard needsSaving, let persistenceFile else { return }
        let temporaryPrefix = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path + "/"
        let temporaryURLPrefix = FileManager.default.temporaryDirectory.path + "/"
        let persistentEntries = entriesByPath.filter { path, _ in
            persistsTemporaryFiles
                || (!path.hasPrefix(temporaryPrefix) && !path.hasPrefix(temporaryURLPrefix)
                    && !path.hasPrefix("/tmp/") && !path.hasPrefix("/private/tmp/"))
        }
        guard let data = try? JSONEncoder().encode(Snapshot(version: Self.snapshotLayoutVersion, entries: persistentEntries)),
            data.count <= Self.maximumSnapshotByteCount
        else { return }
        do {
            try FileManager.default.createDirectory(
                at: persistenceFile.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            // No data protection class: on macOS 26.5 a file written with `.completeFileProtectionUnlessOpen` could not
            // be read again ("Operation not permitted"), so no launch reused the cache. The owner-only permissions keep it private.
            try data.write(to: persistenceFile, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: persistenceFile.path)
            needsSaving = false
        } catch {
        }
    }
}
