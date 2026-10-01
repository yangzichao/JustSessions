import Testing
@testable import JustSessions

struct SessionAttentionReasonTests {
    @Test func aTurnThatEndsCallsYouBack() {
        #expect(SessionAttentionReason.reason(changingFrom: .working, to: .idle) == .finishedTurn)
    }

    @Test func aPromptThatStopsTheCLICallsYouBackWithItsReason() {
        #expect(SessionAttentionReason.reason(changingFrom: .working, to: .needsInput(reason: "input needed"))
            == .needsInput(reason: "input needed"))
        #expect(SessionAttentionReason.reason(changingFrom: .idle, to: .needsInput(reason: nil)) == .needsInput(reason: nil))
    }

    @Test func staysQuietOtherwise() {
        let quietChanges: [(CLIActivity?, CLIActivity?)] = [
            (nil, .idle),
            (nil, .needsInput(reason: nil)),
            (nil, .working),
            (.idle, .working),
            (.idle, .idle),
            (.working, .working),
            (.working, nil),
            (.needsInput(reason: nil), .working),
            (.needsInput(reason: nil), .idle),
            (.needsInput(reason: "input needed"), .needsInput(reason: "dialog open")),
        ]
        for (previous, current) in quietChanges {
            #expect(SessionAttentionReason.reason(changingFrom: previous, to: current) == nil)
        }
    }
}
