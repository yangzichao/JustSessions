import Foundation

struct ConversationDiscoveryCancellation: Sendable {
    private let isCancelledImpl: @Sendable () -> Bool

    init(isCancelled: @escaping @Sendable () -> Bool) {
        isCancelledImpl = isCancelled
    }

    var isCancelled: Bool { isCancelledImpl() }

    func checkCancellation() throws {
        if isCancelled { throw CancellationError() }
    }

    static let never = ConversationDiscoveryCancellation { false }
}

protocol ConversationAdapter: Sendable {
    var provider: ConversationProvider { get }
    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation]
    func arguments(for conversation: Conversation, action: ConversationAction) -> [String]
    func delete(_ conversation: Conversation) throws
}

extension ConversationAdapter {
    func discover() throws -> [Conversation] {
        try discover(cancellation: .never)
    }
}
