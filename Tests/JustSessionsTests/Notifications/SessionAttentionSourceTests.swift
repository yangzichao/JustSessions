import Foundation
import Testing
@testable import JustSessions

struct SessionAttentionSourceTests {
    @Test func survivesTheTripThroughANotification() {
        let sources: [SessionAttentionSource] = [
            .tab(id: UUID(), conversationID: "a"),
            .tab(id: UUID(), conversationID: nil),
            .detachedTmux(conversationID: "b"),
        ]
        for source in sources {
            let userInfo: [AnyHashable: Any] = source.userInfo
            #expect(SessionAttentionSource(userInfo: userInfo) == source)
        }
        #expect(SessionAttentionSource(userInfo: [:]) == nil)
        #expect(SessionAttentionSource(userInfo: ["tabID": "not a uuid"]) == nil)
    }

    @Test func aSessionKeepsOneNotificationWhetherItsCLIRunsInATabOrInTmux() {
        let tab = SessionAttentionSource.tab(id: UUID(), conversationID: "a")
        let detached = SessionAttentionSource.detachedTmux(conversationID: "a")

        #expect(tab.notificationIdentifier == detached.notificationIdentifier)
        #expect(SessionAttentionSource.tab(id: UUID(), conversationID: nil).notificationIdentifier
            != SessionAttentionSource.tab(id: UUID(), conversationID: nil).notificationIdentifier)
    }
}
