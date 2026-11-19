import Foundation
import Testing

@testable import JustSessions

struct CodexThreadStatusTests {
    @Test(arguments: [
        (#"{"type":"active","activeFlags":["waitingOnApproval"]}"#, true),
        (#"{"type":"active","activeFlags":["waitingOnUserInput"]}"#, true),
        (#"{"type":"active","activeFlags":[]}"#, false),
        (#"{"type":"idle"}"#, false),
        (#"{"type":"notLoaded"}"#, false),
        (#"{"type":"systemError"}"#, false),
        (#"{"type":"active"}"#, false),
        (#"{"activeFlags":["waitingOnApproval"]}"#, false),
    ])
    func waitsOnYouOnlyWhileActiveWithAWaitingFlag(status: String, isWaitingOnYou: Bool) throws {
        let json = try JSONSerialization.jsonObject(with: Data(status.utf8))

        #expect(CodexThreadStatus.isWaitingOnYou(json) == isWaitingOnYou)
    }

    @Test func aMissingStatusIsNoWait() {
        #expect(!CodexThreadStatus.isWaitingOnYou(nil))
    }
}
