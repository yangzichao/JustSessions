import Foundation
import Testing
@testable import JustSessions

struct PiEntryLinkTests {
    private static func link(_ line: String) -> PiEntryLink? {
        PiEntryLink(line: Data(line.utf8), lineIndex: 7)
    }

    @Test func readsTheLinkFromTheStartOfALineInPisOwnLayout() {
        let user = #"{"type":"message","id":"a1","parentId":null,"timestamp":"2026-09-30T10:00:00.000Z","message":{"role":"user","content":"Hi"}}"#
        let toolResult = #"{"type":"message","id":"b2","parentId":"a1","timestamp":"2026-09-30T10:00:00.000Z","message":{"role":"toolResult","toolCallId":"t1","content":[]}}"#
        let modelChange = #"{"type":"model_change","id":"c3","parentId":"b2","timestamp":"2026-09-30T10:00:00.000Z","provider":"anthropic","modelId":"m"}"#
        let compaction = #"{"type":"compaction","id":"d4","parentId":"c3","timestamp":"2026-09-30T10:00:00.000Z","summary":"s","firstKeptEntryId":"a1"}"#

        #expect(Self.link(user) == PiEntryLink(lineIndex: 7, id: "a1", parentID: nil, mightBeShown: true))
        #expect(Self.link(toolResult) == PiEntryLink(lineIndex: 7, id: "b2", parentID: "a1", mightBeShown: false))
        #expect(Self.link(modelChange) == PiEntryLink(lineIndex: 7, id: "c3", parentID: "b2", mightBeShown: false))
        #expect(Self.link(compaction) == PiEntryLink(lineIndex: 7, id: "d4", parentID: "c3", mightBeShown: true))
    }

    @Test func parsesLinesInAnyOtherLayout() {
        let customMessage = #"{"type":"custom_message","customType":"intercom_message","content":"Hi","display":true,"id":"e5","parentId":"d4","timestamp":"2026-09-30T10:00:00.000Z"}"#
        let reorderedAssistant = #"{"message":{"role":"assistant","content":[]},"type":"message","parentId":"e5","id":"f6"}"#

        #expect(Self.link(customMessage) == PiEntryLink(lineIndex: 7, id: "e5", parentID: "d4", mightBeShown: false))
        #expect(Self.link(reorderedAssistant) == PiEntryLink(lineIndex: 7, id: "f6", parentID: "e5", mightBeShown: true))
    }

    /// Only the first 512 bytes are read without parsing; a value that runs past them is found by parsing the line.
    @Test func anIDOrParentPastTheStartOfTheLineIsFoundByParsingIt() {
        let longID = String(repeating: "a", count: 600)
        let longParent = String(repeating: "b", count: 600)
        let longType = "custom_" + String(repeating: "c", count: 600)
        let longIDLine = #"{"type":"message","id":"\#(longID)","parentId":"p1","timestamp":"2026-09-30T10:00:00.000Z","message":{"role":"user","content":"Hi"}}"#
        let longParentLine = #"{"type":"message","id":"a1","parentId":"\#(longParent)","timestamp":"2026-09-30T10:00:00.000Z","message":{"role":"assistant","content":[]}}"#
        let longTypeLine = #"{"type":"\#(longType)","id":"a2","parentId":"a1","timestamp":"2026-09-30T10:00:00.000Z"}"#

        #expect(Self.link(longIDLine) == PiEntryLink(lineIndex: 7, id: longID, parentID: "p1", mightBeShown: true))
        #expect(Self.link(longParentLine) == PiEntryLink(lineIndex: 7, id: "a1", parentID: longParent, mightBeShown: true))
        #expect(Self.link(longTypeLine) == PiEntryLink(lineIndex: 7, id: "a2", parentID: "a1", mightBeShown: false))
    }

    @Test func theHeaderAndLinesThatAreNotEntriesHaveNoLink() {
        #expect(Self.link(#"{"type":"session","version":3,"id":"019a0000-0000-7000-8000-000000000000","cwd":"/tmp"}"#) == nil)
        #expect(Self.link("not json") == nil)
        #expect(Self.link(#"{"id":"a1","parentId":null}"#) == nil)
        #expect(Self.link(#"{"type":"message","id":"a1","parentId":null,"timestamp":"2026-09-30T10:00:00.000Z","message":{"role":"user","con"#) == nil)
    }
}
