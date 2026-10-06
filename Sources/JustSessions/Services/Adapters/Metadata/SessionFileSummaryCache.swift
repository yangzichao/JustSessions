import Foundation

/// What was read from each session file, kept while the file keeps its size and modification date, so a refresh
/// reads only the files a CLI wrote to since the last one. A file that held nothing worth listing is remembered too.
final class SessionFileSummaryCache<Summary: Sendable & Codable>: @unchecked Sendable {
    private struct Fingerprint: Equatable, Codable {
        let modificationDate: Date
        let size: Int
        let fileNumber: UInt64

        /// Uses the values a directory listing already fetched for `file`, when it fetched them.
        init?(file: URL) {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modificationDate = values.contentModificationDate,
                  let size = values.fileSize,
                  let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                  let fileNumber = attributes[.systemFileNumber] as? NSNumber else { return nil }
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

    /// Called on the discovery worker. A cache is disposable; incompatible/corrupt snapshots are ignored.
    private func loadSnapshotIfNeeded() {
        guard !hasLoadedSnapshot else { return }
        hasLoadedSnapshot = true
        guard let persistenceFile,
              let size = try? persistenceFile.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 64 << 20,
              let data = try? Data(contentsOf: persistenceFile),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data), snapshot.version == 1 else { return }
        entriesByPath = snapshot.entries
    }

    /// The summary kept for `file` if the file has not changed since, or else what `read` makes of it now.
    func summary(of file: URL, read: (URL) -> Summary?) -> Summary? {
        // Taken before reading: a write landing during the read then shows as a change at the next refresh.
        guard let fingerprint = Fingerprint(file: file) else { return read(file) }
        let path = file.path
        if let entry = lock.withLock({ loadSnapshotIfNeeded(); return entriesByPath[path] }), entry.fingerprint == fingerprint {
            return entry.summary
        }
        let summary = read(file)
        lock.withLock {
            entriesByPath[path] = Entry(fingerprint: fingerprint, summary: summary)
            needsSaving = true
        }
        return summary
    }

    /// Forgets the files in `directory` that a scan of it no longer found, such as deleted sessions.
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

    /// One atomic write at the end of discovery, serialized with other hosts' writes. Temporary fixtures stay out.
    private func saveSnapshotIfNeeded() {
        guard needsSaving, let persistenceFile else { return }
        let temporaryPrefix = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path + "/"
        let temporaryURLPrefix = FileManager.default.temporaryDirectory.path + "/"
        let persistentEntries = entriesByPath.filter { path, _ in
            persistsTemporaryFiles || (!path.hasPrefix(temporaryPrefix) && !path.hasPrefix(temporaryURLPrefix)
                && !path.hasPrefix("/tmp/") && !path.hasPrefix("/private/tmp/"))
        }
        guard let data = try? JSONEncoder().encode(Snapshot(version: 1, entries: persistentEntries)), data.count <= 64 << 20 else { return }
        do {
            try FileManager.default.createDirectory(at: persistenceFile.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            // No data protection class: on macOS 26.5 a file written with `.completeFileProtectionUnlessOpen` could not
            // be read again ("Operation not permitted"), so no launch reused the cache. The owner-only permissions keep it private.
            try data.write(to: persistenceFile, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: persistenceFile.path)
            needsSaving = false
        } catch { /* Rebuild from the source files when a cache cannot be saved. */ }
    }
}
