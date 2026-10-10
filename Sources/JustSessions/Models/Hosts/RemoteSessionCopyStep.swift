import Foundation

/// The tool whose sessions an SSH host's refresh is copying now, and how far it is through the tools. A refresh copies
/// one tool after another and lists each tool's sessions as soon as they are copied.
struct RemoteSessionCopyStep: Equatable, Sendable {
    let provider: ConversationProvider
    /// Counts from 1.
    let number: Int
    let count: Int

    var isLast: Bool { number == count }
}
