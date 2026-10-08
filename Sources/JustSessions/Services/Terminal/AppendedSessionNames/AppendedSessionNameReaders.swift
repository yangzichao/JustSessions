import Foundation

/// One `AppendedJSONLinesReader` per file that open tabs' names are followed in, kept from one look to the next.
@MainActor
final class AppendedSessionNameReaders {
    private var readersByFile: [URL: AppendedJSONLinesReader] = [:]

    /// The lines appended to `file` since the last look; none the first time, which marks where the file ends.
    func newLines(in file: URL) -> [Data] {
        var reader = readersByFile[file] ?? AppendedJSONLinesReader(file: file)
        let lines = reader.newLines()
        readersByFile[file] = reader
        return lines
    }

    /// Forgets the files no open tab follows any more, so reopening one starts again from its end.
    func keepOnly(_ files: Set<URL>) {
        readersByFile = readersByFile.filter { files.contains($0.key) }
    }
}
