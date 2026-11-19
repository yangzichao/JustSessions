import Foundation

struct SSHAskpassRequest: Codable, Equatable, Sendable {
    let prompt: String
    /// `confirm` for a yes or no question, `none` for a notice that needs no answer, such as touching a security
    /// key; nil for text to type.
    let hint: String?
}

struct SSHAskpassReply: Codable, Equatable, Sendable {
    let answer: String?
}

enum SSHAskpassMessageLine {
    /// Longer than any prompt or answer `ssh` handles; a line past it is not read.
    static let maximumLength = 64 << 10

    static func encoded(_ message: some Encodable) -> Data? {
        guard var data = try? JSONEncoder().encode(message) else { return nil }
        data.append(UInt8(ascii: "\n"))
        return data
    }

    static func decoded<Message: Decodable>(_ type: Message.Type, from data: Data) -> Message? {
        guard let end = data.firstIndex(of: UInt8(ascii: "\n")) else { return nil }
        return try? JSONDecoder().decode(type, from: data[data.startIndex..<end])
    }
}
