import Foundation
import Testing
@testable import JustSessions

struct OpenCodeConversationOutlineTests {
    @Test func appendsAndMutableTailDecodeOnlyTheTailButEarlierEditsRebuild() throws {
        let fixture = try OpenCodeTranscriptReaderFixture()
        defer { fixture.remove() }
        let database = fixture.database
        let sessionID = "ses_prefix_proof"
        try database.addSession(sessionID)
        // Cross the digest staging-buffer boundary and include a column larger than that buffer.
        try database.addUserPrompts((0..<600).map {
            $0 == 100 ? String(repeating: "Café 🧪 ", count: 20_000) : "Original message \($0)"
        }, session: sessionID)
        let conversation = Conversation.fixture(provider: .opencode, sessionID: sessionID, sourceFile: database.file)
        let empty = ConversationOutline(blocks: [])
        let initial = try OpenCodeConversationOutline.read(conversation, extending: empty, prefix: nil)
        #expect(initial.decodedRecordCount == 600)

        try database.addAssistantReply("msg_z", session: sessionID, createdAt: 601, text: "First version of final reply")
        let appended = try OpenCodeConversationOutline.read(conversation, extending: initial.outline, prefix: initial.prefix)
        #expect(appended.decodedRecordCount == 2)
        #expect(appended.outline == (try OpenCodeConversationOutline.read(conversation, extending: empty, prefix: nil)).outline)

        try database.execute("UPDATE part SET data = ? WHERE message_id = ?", [#"{"type":"text","text":"Completely rewritten final reply"}"#, "msg_z"])
        let streamed = try OpenCodeConversationOutline.read(conversation, extending: appended.outline, prefix: appended.prefix)
        #expect(streamed.decodedRecordCount == 1)
        #expect(streamed.outline.blocks.last?.snippet == "Completely rewritten final reply")

        // Keep timestamps and the final anchor unchanged: only hashing the retained visible columns detects this.
        try database.execute("UPDATE part SET data = ? WHERE message_id = ?", [#"{"type":"text","text":"Rewritten earlier message"}"#, "msg_000050"])
        let rewritten = try OpenCodeConversationOutline.read(conversation, extending: streamed.outline, prefix: streamed.prefix)
        #expect(rewritten.decodedRecordCount == 601)
        #expect(rewritten.outline == (try OpenCodeConversationOutline.read(conversation, extending: empty, prefix: nil)).outline)

        try database.execute("DELETE FROM part WHERE message_id = 'msg_z'; DELETE FROM message WHERE id = 'msg_z'")
        let removedTail = try OpenCodeConversationOutline.read(conversation, extending: rewritten.outline, prefix: rewritten.prefix)
        #expect(removedTail.outline.blocks.count == 600)
        #expect(removedTail.outline == (try OpenCodeConversationOutline.read(conversation, extending: empty, prefix: nil)).outline)
    }
}
