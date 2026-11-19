import Testing

@testable import JustSessions

struct SessionModelTests {
    @Test func noModelAndClaudesSyntheticMarkerAreNoModel() {
        #expect(SessionModel(id: nil) == nil)
        #expect(SessionModel(id: "  ") == nil)
        #expect(SessionModel(id: "<synthetic>") == nil)
    }

    @Test func theLabelAddsTheEffortWhenThereIsOne() {
        #expect(SessionModel(id: "gpt-5.5", effort: "medium")?.label == "gpt-5.5 · medium")
        #expect(SessionModel(id: "gpt-5.5", effort: " ")?.label == "gpt-5.5")
        #expect(SessionModel(id: "claude-opus-4-8")?.label == "claude-opus-4-8")
    }

    @Test func theShortNameLeavesOutClaudesPrefixAndATrailingDate() {
        #expect(SessionModel(id: "claude-haiku-4-5-20251001")?.shortName == "haiku-4-5")
        #expect(SessionModel(id: "claude-opus-4-8")?.shortName == "opus-4-8")
        #expect(SessionModel(id: "claude-fable-5")?.shortName == "fable-5")
        #expect(SessionModel(id: "gpt-6-astra")?.shortName == "gpt-6-astra")
        #expect(SessionModel(id: "kimi-k3")?.shortName == "kimi-k3")
        #expect(SessionModel(id: "claude-")?.shortName == "claude-")
    }
}
