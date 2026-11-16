import Foundation

/// Serial file reads and name extraction for open tabs, kept off the main actor. Each file keeps its reader between looks.
actor AppendedSessionNameReaders {
    struct Lookup: Sendable {
        let tabID: UUID
        let conversation: Conversation
        let file: URL
    }

    struct Name: Sendable {
        let lookup: Lookup
        let value: String
    }

    private var readersByFile: [URL: AppendedJSONLinesReader] = [:]
    private let readLines: @Sendable (inout AppendedJSONLinesReader) -> [Data]

    init(readLines: @escaping @Sendable (inout AppendedJSONLinesReader) -> [Data] = { $0.newLines() }) {
        self.readLines = readLines
    }

    /// Reads a shared file once, then extracts each tab's name. The first look marks its end and returns no old names.
    func names(for lookups: [Lookup]) -> [Name] {
        let lookupsByFile = Dictionary(grouping: lookups, by: \.file)
        readersByFile = readersByFile.filter { lookupsByFile[$0.key] != nil }
        var names: [Name] = []
        for (file, targets) in lookupsByFile {
            var reader = readersByFile[file] ?? AppendedJSONLinesReader(file: file)
            let lines = readLines(&reader)
            readersByFile[file] = reader
            guard !lines.isEmpty else { continue }
            for target in targets {
                if let name = AppendedSessionNameSource.latestName(for: target.conversation, amongLines: lines) {
                    names.append(Name(lookup: target, value: name))
                }
            }
        }
        return names
    }
}
