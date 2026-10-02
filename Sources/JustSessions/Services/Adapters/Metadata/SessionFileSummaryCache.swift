import Foundation

/// What was read from each session file, kept while the file keeps its size and modification date, so a refresh
/// reads only the files a CLI wrote to since the last one. A file that held nothing worth listing is remembered too.
final class SessionFileSummaryCache<Summary: Sendable>: @unchecked Sendable {
    private struct Fingerprint: Equatable {
        let modificationDate: Date
        let size: Int

        /// Uses the values a directory listing already fetched for `file`, when it fetched them.
        init?(file: URL) {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modificationDate = values.contentModificationDate,
                  let size = values.fileSize else { return nil }
            self.modificationDate = modificationDate
            self.size = size
        }
    }

    private struct Entry {
        let fingerprint: Fingerprint
        let summary: Summary?
    }

    private let lock = NSLock()
    private var entriesByPath: [String: Entry] = [:]

    /// The summary kept for `file` if the file has not changed since, or else what `read` makes of it now.
    func summary(of file: URL, read: (URL) -> Summary?) -> Summary? {
        // Taken before reading: a write landing during the read then shows as a change at the next refresh.
        guard let fingerprint = Fingerprint(file: file) else { return read(file) }
        let path = file.path
        if let entry = lock.withLock({ entriesByPath[path] }), entry.fingerprint == fingerprint {
            return entry.summary
        }
        let summary = read(file)
        lock.withLock { entriesByPath[path] = Entry(fingerprint: fingerprint, summary: summary) }
        return summary
    }

    /// Forgets the files in `directory` that a scan of it no longer found, such as deleted sessions.
    func forgetFiles(in directory: URL, except foundFiles: [URL]) {
        let directoryPrefix = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
        let foundPaths = Set(foundFiles.map(\.path))
        lock.withLock {
            entriesByPath = entriesByPath.filter { path, _ in
                !path.hasPrefix(directoryPrefix) || foundPaths.contains(path)
            }
        }
    }
}
