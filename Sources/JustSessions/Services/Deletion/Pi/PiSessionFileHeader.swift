import Foundation

/// The header Pi writes as the first line of a session file, such as
/// `{"type":"session","version":3,"id":"…","timestamp":"…","cwd":"…"}`. Only what tells which session the file
/// holds is decoded.
struct PiSessionFileHeader: Decodable {
    /// How far into the file the header's line must end.
    private static let maximumLineLength = 65_536

    /// `session` for a header.
    let type: String
    let id: String

    /// Nil when `file` cannot be read, its first line does not end within `maximumLineLength` bytes, or that line is
    /// not a JSON object with a string `type` and `id`.
    init?(firstLineOf file: URL) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: Self.maximumLineLength),
              let newline = data.firstIndex(of: UInt8(ascii: "\n")),
              let header = try? JSONDecoder().decode(Self.self, from: data[..<newline]) else { return nil }
        self = header
    }
}
