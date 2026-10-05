import Foundation
import Testing
@testable import JustSessions

struct AntigravityCLILogTests {
    static let firstConversationID = "a24e0f54-5565-4110-9abb-5069fc113862"
    static let secondConversationID = "cc11d3bc-b1fb-4099-a72a-5436dece254d"

    /// A line as Antigravity CLI 1.2.16 logs it.
    static func streamLine(for conversationID: String) -> String {
        "I1004 15:55:03.777079     316 server.go:1272] Starting conversation update stream for \(conversationID)\n"
    }

    @Test func theLastStreamLineNamesTheConversation() {
        let log = Self.streamLine(for: Self.firstConversationID)
            + "I1004 15:55:37.838731     667 server.go:1325] Stream goroutine exited for \(Self.firstConversationID)\n"
            + Self.streamLine(for: Self.secondConversationID)
            + "I1004 15:55:46.195270    1209 server.go:1840] Sending user message to conversation \(Self.firstConversationID)\n"

        #expect(AntigravityCLILog.lastConversationID(in: log) == Self.secondConversationID)
    }

    @Test func aStreamLineWithoutAConversationIDIsSkipped() {
        let log = Self.streamLine(for: Self.firstConversationID) + Self.streamLine(for: "not-a-conversation")

        #expect(AntigravityCLILog.lastConversationID(in: log) == Self.firstConversationID)
        #expect(AntigravityCLILog.lastConversationID(in: "I1004 server.go:1263] Created conversation \(Self.firstConversationID)\n") == nil)
    }

    @Test func recognizesTheCLIsLogInAntigravitysFolder() {
        let configurationDirectory = URL(fileURLWithPath: "/Users/me/.gemini/antigravity-cli")

        #expect(AntigravityCLILog.isCLILog(atPath: "/Users/me/.gemini/antigravity-cli/log/cli-20261004_155442.log", configurationDirectory: configurationDirectory))
        #expect(!AntigravityCLILog.isCLILog(atPath: "/Users/me/.gemini/antigravity-cli/crashes/crash_24650.log", configurationDirectory: configurationDirectory))
        #expect(!AntigravityCLILog.isCLILog(atPath: "/Users/me/.gemini/antigravity-cli/log/language_server.log", configurationDirectory: configurationDirectory))
        #expect(!AntigravityCLILog.isCLILog(atPath: "/Users/me/elsewhere/log/cli-20261004_155442.log", configurationDirectory: configurationDirectory))
    }
}
