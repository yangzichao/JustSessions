import Foundation
import Testing
@testable import JustSessions

struct ConversationTitleAliasesTests {
    @Test func sameSessionIDOnAnotherHostKeepsItsOwnTitle() {
        let sessionID = UUID().uuidString.lowercased()
        let onThisMac = Conversation.fixture(sessionID: sessionID, title: "On this Mac")
        let onDevbox = Conversation.fixture(sessionID: sessionID, title: "On devbox", host: .ssh("devbox"))
        var aliases = ConversationTitleAliases()

        aliases.rename(onThisMac, to: "Renamed")

        #expect(aliases.title(for: onThisMac) == "Renamed")
        #expect(aliases.title(for: onDevbox) == "On devbox")
    }

    @Test func savedTitlesLoadBackUnchanged() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        var aliases = ConversationTitleAliases()
        aliases.rename(.fixture(title: "a"), to: "Überarbeitung 🚀")
        aliases.rename(.fixture(title: "b"), to: "two\nlines inside")
        aliases.rename(.fixture(title: "c", host: .ssh("me@devbox")), to: "Remote")

        aliases.save(to: isolatedUserDefaults.userDefaults)

        #expect(ConversationTitleAliases.load(from: isolatedUserDefaults.userDefaults) == aliases)
    }

    @Test func aSettingOfTheWrongShapeLoadsAsNoCustomTitles() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }

        isolatedUserDefaults.userDefaults.set("not a dictionary", forKey: ConversationTitleAliases.userDefaultsKey)
        #expect(ConversationTitleAliases.load(from: isolatedUserDefaults.userDefaults) == ConversationTitleAliases())

        isolatedUserDefaults.userDefaults.set(["claude:1": 42], forKey: ConversationTitleAliases.userDefaultsKey)
        #expect(ConversationTitleAliases.load(from: isolatedUserDefaults.userDefaults) == ConversationTitleAliases())
    }

    /// Random renames and removals over a few conversations. After each step the renamed conversation shows the
    /// trimmed title (or its suggested one), no other conversation's title changes, and no stored title is blank,
    /// padded, or just the suggested title.
    @Test func randomRenamesKeepEveryTitleConsistent() {
        var generator = SeededRandomNumberGenerator(seed: 0xA11A5)
        let conversations = (0..<5).map { Conversation.fixture(title: "Suggested \($0)") }
        let suggestedTitlesByID = Dictionary(uniqueKeysWithValues: conversations.map { ($0.id, $0.suggestedTitle) })
        let proposedTitles = ["", "  ", "\n", "Custom", "  Custom  ", "Other\n", "Suggested 0", " Suggested 1 ", "Suggested 2"]
        var aliases = ConversationTitleAliases()

        for _ in 0..<1_000 {
            let conversation = conversations.randomElement(using: &generator)!
            let titlesBefore = conversations.map { aliases.title(for: $0) }
            if Int.random(in: 0..<5, using: &generator) == 0 {
                aliases.removeTitle(forConversationID: conversation.id)
                #expect(aliases.title(for: conversation) == conversation.suggestedTitle)
            } else {
                let proposedTitle = proposedTitles.randomElement(using: &generator)!
                aliases.rename(conversation, to: proposedTitle)
                let trimmedTitle = proposedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(aliases.title(for: conversation) == (trimmedTitle.isEmpty ? conversation.suggestedTitle : trimmedTitle))
            }

            for (index, other) in conversations.enumerated() where other.id != conversation.id {
                #expect(aliases.title(for: other) == titlesBefore[index])
            }
            for (conversationID, customTitle) in aliases.customTitlesByConversationID {
                #expect(!customTitle.isEmpty)
                #expect(customTitle == customTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                #expect(customTitle != suggestedTitlesByID[conversationID])
            }
        }
    }
}
