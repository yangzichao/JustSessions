import Foundation

/// A CLI on this Mac whose activity can call you back: a tab's, or one running in tmux with no tab open.
enum SessionAttentionSource: Hashable, Sendable {
    /// `conversationID` is nil for a new session's tab until its session is known.
    case tab(id: UUID, conversationID: String?)
    case detachedTmux(conversationID: String)

    var tabID: UUID? {
        if case .tab(let id, _) = self { return id }
        return nil
    }

    var conversationID: String? {
        switch self {
        case .tab(_, let conversationID): conversationID
        case .detachedTmux(let conversationID): conversationID
        }
    }

    /// Every name the CLI's last activity is kept under. A tab goes by its own id and, once known, by its session's,
    /// so its CLI stays followed when the tab learns its session or closes with the CLI left running in tmux.
    var activityKeys: [String] {
        switch self {
        case .tab(let id, let conversationID): [Self.tabKey(id)] + (conversationID.map { [$0] } ?? [])
        case .detachedTmux(let conversationID): [conversationID]
        }
    }

    /// Names one notification per session, so a newer one replaces the one before.
    var notificationIdentifier: String {
        switch self {
        case .tab(let id, let conversationID): "session-attention." + (conversationID ?? Self.tabKey(id))
        case .detachedTmux(let conversationID): "session-attention." + conversationID
        }
    }

    private static func tabKey(_ id: UUID) -> String {
        "tab:" + id.uuidString
    }

    // MARK: - Notification payload

    private static let tabIDKey = "tabID"
    private static let conversationIDKey = "conversationID"

    /// Carried by the notification, so a click knows which session to show.
    var userInfo: [String: String] {
        var userInfo: [String: String] = [:]
        if let tabID { userInfo[Self.tabIDKey] = tabID.uuidString }
        if let conversationID { userInfo[Self.conversationIDKey] = conversationID }
        return userInfo
    }

    init?(userInfo: [AnyHashable: Any]) {
        let conversationID = userInfo[Self.conversationIDKey] as? String
        if let tabID = (userInfo[Self.tabIDKey] as? String).flatMap(UUID.init(uuidString:)) {
            self = .tab(id: tabID, conversationID: conversationID)
        } else if let conversationID {
            self = .detachedTmux(conversationID: conversationID)
        } else {
            return nil
        }
    }
}
