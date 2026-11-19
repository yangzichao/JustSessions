import Foundation

struct PiSessionFileHeader: Decodable {
    private static let maximumLineLength = 65_536

    let type: String
    let id: String

    init?(firstLineOf file: URL) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: Self.maximumLineLength),
            let newline = data.firstIndex(of: UInt8(ascii: "\n")),
            let header = try? JSONDecoder().decode(Self.self, from: data[..<newline])
        else { return nil }
        self = header
    }
}
