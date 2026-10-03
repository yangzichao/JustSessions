import Foundation
import Testing
@testable import JustSessions

struct ConversationExportLoadingTests {
    @Test(arguments: ConversationProvider.allCases)
    func exportsEverySavedEntryAndUncutMessagesFromLocalOrMirroredFiles(_ provider: ConversationProvider) async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = try ConversationExportFixture.conversation(provider: provider, in: directory)
        guard case .loaded(let preview) = try await TranscriptLoader.load(conversation) else {
            Issue.record("Missing preview")
            return
        }
        #expect(preview.omittedEntryCount == 2)
        #expect(preview.entries.last?.content != .userMessage(ConversationExportFixture.longMessage))

        for host: SessionHost in [.thisMac, .ssh("devbox")] {
            let selection = ConversationExportSelection(conversation: conversation.onHost(host), title: "Renamed 对话")
            let document = try await ConversationExportDocument.load([selection])
            #expect(document.sessions[0].transcript.entries.count == ConversationExportFixture.entryCount)
            #expect(document.sessions[0].transcript.omittedEntryCount == 0)
            #expect(document.sessions[0].transcript.entries.last?.content == .userMessage(ConversationExportFixture.longMessage))
            let markdown = try await document.text(in: .markdown)
            #expect(markdown.hasPrefix("# Renamed 对话\n"))
            #expect(markdown.contains(ConversationExportFixture.longMessage))
            #expect(markdown.contains("Host: \(host.displayName)"))
        }
    }

    @Test func emptyAndMissingSessionsProduceExplicitErrors() async throws {
        await #expect(throws: ConversationExportError.self) { try await ConversationExportDocument.load([]) }
        let missing = ConversationExportSelection(conversation: .fixture(), title: "Missing")
        await #expect(throws: ConversationExportError.self) { try await ConversationExportDocument.load([missing]) }
        let file = try TranscriptTestFiles.write([])
        defer { try? FileManager.default.removeItem(at: file) }
        let empty = ConversationExportSelection(conversation: .fixture(sourceFile: file), title: "Empty")
        await #expect(throws: ConversationExportError.self) { try await ConversationExportDocument.load([empty]) }
    }

    @Test func cancelledReadDoesNotReturnAPartialDocument() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ConversationExportDocument.load([ConversationExportSelection(conversation: .fixture(), title: "Cancelled")])
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
