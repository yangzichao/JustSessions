import Foundation
import Testing
@testable import JustSessions

struct PiPreviewedEntryTests {
    @Test func namesEachKindThePreviewShows() {
        #expect(PiPreviewedEntry(entryType: "message", role: "user") == .userMessage)
        #expect(PiPreviewedEntry(entryType: "message", role: "bashExecution") == .shellCommand)
        #expect(PiPreviewedEntry(entryType: "message", role: "assistant") == .assistantMessage)
        #expect(PiPreviewedEntry(entryType: "message", role: "toolResult") == .toolResult)
        #expect(PiPreviewedEntry(entryType: "compaction", role: nil) == .compaction)
        #expect(PiPreviewedEntry(entryType: "branch_summary", role: nil) == .branchSummary)
    }

    @Test func leavesOutEverythingElse() {
        let leftOut: [(String, String?)] = [
            ("message", "system"),
            ("message", "hookMessage"),
            ("message", nil),
            ("custom_message", nil),
            ("custom", nil),
            ("model_change", nil),
            ("thinking_level_change", nil),
            ("label", nil),
            ("session_info", nil),
            ("session", nil),
            ("user", nil),
        ]

        for (entryType, role) in leftOut {
            #expect(PiPreviewedEntry(entryType: entryType, role: role) == nil, "\(entryType) \(role ?? "nil")")
        }
    }

    /// A role belongs to a message, so it does not change what another entry type shows as.
    @Test func onlyMessagesAreJudgedByTheirRole() {
        #expect(PiPreviewedEntry(entryType: "compaction", role: "toolResult") == .compaction)
        #expect(PiPreviewedEntry(entryType: "custom_message", role: "user") == nil)
    }

    /// Only a tool result's images are shown, so one without an image part is not worth decoding.
    @Test func aToolResultMightBeShownOnlyWhenItsLineMentionsAnImagePart() {
        let textOnly = Data(#"{"type":"message","message":{"role":"toolResult","content":[{"type":"text","text":"ok"}]}}"#.utf8)
        let withImage = Data(#"{"type":"message","message":{"role":"toolResult","content":[{"type":"text","text":"Screenshot:"},{"type":"image","data":"AAAA","mimeType":"image/png"}]}}"#.utf8)

        #expect(PiPreviewedEntry.toolResult.mightBeShown(in: textOnly) == false)
        #expect(PiPreviewedEntry.toolResult.mightBeShown(in: withImage))
        #expect(PiPreviewedEntry.userMessage.mightBeShown(in: textOnly))
        #expect(PiPreviewedEntry.compaction.mightBeShown(in: textOnly))
    }
}
