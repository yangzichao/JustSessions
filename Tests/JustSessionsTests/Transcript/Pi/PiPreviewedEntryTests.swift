import Testing
@testable import JustSessions

struct PiPreviewedEntryTests {
    @Test func namesEachKindThePreviewShows() {
        #expect(PiPreviewedEntry(entryType: "message", role: "user") == .userMessage)
        #expect(PiPreviewedEntry(entryType: "message", role: "bashExecution") == .shellCommand)
        #expect(PiPreviewedEntry(entryType: "message", role: "assistant") == .assistantMessage)
        #expect(PiPreviewedEntry(entryType: "compaction", role: nil) == .compaction)
        #expect(PiPreviewedEntry(entryType: "branch_summary", role: nil) == .branchSummary)
    }

    @Test func leavesOutEverythingElse() {
        let leftOut: [(String, String?)] = [
            ("message", "toolResult"),
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
}
