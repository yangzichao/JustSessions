import Testing
@testable import JustSessions

struct SessionDeletionLocalizationTests {
    private let chinese = AppInterfaceLanguage(identifier: "zh-Hans")

    @Test func destructiveRemoteWarningPreservesDestinationAndExplainsPermanence() {
        let conversation = Conversation.fixture(provider: .pi, host: .ssh("me@build"))
        #expect(SessionDeletionConfirmationText.message(forDeleting: conversation, language: chinese)
            == "me@build 上的 Pi 会话文件及其关联文件夹将被永久删除。SSH 主机没有废纸篓，此操作无法撤销。")
    }

    @Test func skippedCountsAndDeletionCountAreTranslatedAsCompleteSentences() {
        let plan = SessionDeletionPlan(deletableConversations: [.fixture(), .fixture()], openTerminalCount: 2)
        #expect(SessionDeletionConfirmationText.buttonTitle(for: plan, language: chinese) == "删除 2 个会话")
        #expect(SessionDeletionConfirmationText.skippedSessionsSentence(for: plan, language: chinese)
            == "将跳过 2 个终端已打开的会话。")
    }

    @Test func subagentCountsAreTranslatedAsCompleteSentences() {
        let plan = SessionDeletionPlan(
            deletableConversations: [.fixture()], openTerminalCount: 0, deletedSubagentCount: 118, keptSubagentCount: 2
        )
        #expect(SessionDeletionConfirmationText.subagentSentences(for: plan, language: chinese)
            == ["同时会删除 118 个子代理会话。", "2 个子代理会话将保留在磁盘上。"])
    }
}
