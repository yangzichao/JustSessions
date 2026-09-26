import Testing
@testable import JustSessions

struct ToolCallSummaryTests {
    @Test func theMostDescriptiveArgumentIsShown() {
        let summary = ToolCallSummary.summary(toolName: "Bash", arguments: ["description": "Show status", "command": "git status"])
        #expect(summary == "Bash · git status")
    }

    @Test func anyTextArgumentIsShownWhenNoneIsKnown() {
        let summary = ToolCallSummary.summary(toolName: "Custom", arguments: ["zeta": "last", "alpha": "first", "count": 3])
        #expect(summary == "Custom · first")
    }

    @Test func aCommandGivenAsWordsIsJoined() {
        let summary = ToolCallSummary.summary(toolName: "shell", arguments: ["command": ["bash", "-lc", "swift test"]])
        #expect(summary == "shell · bash -lc swift test")
    }

    @Test func onlyTheFirstLineWithTextIsShown() {
        let summary = ToolCallSummary.summary(toolName: "Write", arguments: ["file_path": "\n\n  /tmp/notes.txt  \nsecond line"])
        #expect(summary == "Write · /tmp/notes.txt")
    }

    @Test func aBlankArgumentGivesWayToTheNextOne() {
        let summary = ToolCallSummary.summary(toolName: "Grep", arguments: ["path": "  ", "pattern": "TODO"])
        #expect(summary == "Grep · TODO")
    }

    @Test(arguments: [
        [:],
        ["todos": [["content": "Write tests"]]],
        ["command": " \n\t "],
        ["timeout": 30],
    ] as [[String: any Sendable]])
    func withoutADescriptiveArgumentOnlyTheToolIsNamed(_ arguments: [String: any Sendable]) {
        #expect(ToolCallSummary.summary(toolName: "Tool", arguments: arguments) == "Tool")
    }

    @Test func longSummariesAreCutWithAnEllipsis() {
        let summary = ToolCallSummary.summary(toolName: "Bash", arguments: ["command": String(repeating: "a", count: 1_000)])
        #expect(summary.count == ToolCallSummary.maximumLength + 1)
        #expect(summary.hasPrefix("Bash · aaaa"))
        #expect(summary.hasSuffix("a…"))
    }

    @Test func freeformInputShowsItsFirstLine() {
        let summary = ToolCallSummary.summary(toolName: "apply_patch", freeformInput: "*** Begin Patch\n*** Update File: App.swift")
        #expect(summary == "apply_patch · *** Begin Patch")
        #expect(ToolCallSummary.summary(toolName: "apply_patch", freeformInput: "") == "apply_patch")
    }
}
