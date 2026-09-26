import Foundation
import Testing
@testable import JustSessions

/// The arguments each CLI starts with. They are the tools' own command-line interfaces, so a change here has to
/// follow a change in the tool.
struct CLIArgumentContractTests {
    struct ArgumentCase: Sendable, CustomTestStringConvertible {
        let provider: ConversationProvider
        let action: ConversationAction
        let expectedArguments: [String]
        var testDescription: String { "\(provider.rawValue) \(action.displayName)" }
    }

    static let sessionID = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"

    static let argumentCases = [
        ArgumentCase(provider: .claude, action: .new, expectedArguments: []),
        ArgumentCase(provider: .claude, action: .resume, expectedArguments: ["--resume", sessionID]),
        ArgumentCase(provider: .claude, action: .branch, expectedArguments: ["--resume", sessionID, "--fork-session"]),
        ArgumentCase(provider: .codex, action: .new, expectedArguments: []),
        ArgumentCase(provider: .codex, action: .resume, expectedArguments: ["resume", sessionID]),
        ArgumentCase(provider: .codex, action: .branch, expectedArguments: ["fork", sessionID]),
        ArgumentCase(provider: .antigravity, action: .new, expectedArguments: []),
        ArgumentCase(provider: .antigravity, action: .resume, expectedArguments: ["--conversation", sessionID]),
        ArgumentCase(provider: .antigravity, action: .branch, expectedArguments: ["--conversation", sessionID]),
    ]

    @Test(arguments: argumentCases)
    func eachToolStartsWithItsOwnArguments(_ argumentCase: ArgumentCase) {
        let conversation = Conversation.fixture(provider: argumentCase.provider, sessionID: Self.sessionID)
        let arguments = adapter(for: argumentCase.provider).arguments(for: conversation, action: argumentCase.action)
        #expect(arguments == argumentCase.expectedArguments)
    }

    @Test func everyToolAndActionHasACase() {
        let coveredCases = Set(Self.argumentCases.map { "\($0.provider.rawValue) \($0.action.displayName)" })
        #expect(coveredCases.count == ConversationProvider.allCases.count * ConversationAction.allCases.count)
    }

    @Test func onlyResumeContinuesTheSameSession() {
        #expect(ConversationAction.allCases.map(\.displayName) == ["New", "Resume", "Branch"])
        #expect(ConversationAction.allCases.filter(\.startsNewSession) == [.new, .branch])
    }

    private func adapter(for provider: ConversationProvider) -> any ConversationAdapter {
        let unusedDirectory = URL(fileURLWithPath: "/nonexistent/justsessions-tests")
        return switch provider {
        case .claude: ClaudeAdapter(configurationDirectory: unusedDirectory)
        case .codex: CodexAdapter(codexDirectory: unusedDirectory)
        case .antigravity: AntigravityAdapter(configurationDirectory: unusedDirectory)
        }
    }
}
