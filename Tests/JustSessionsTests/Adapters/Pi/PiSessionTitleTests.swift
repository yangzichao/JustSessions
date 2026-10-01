import Testing
@testable import JustSessions

struct PiSessionTitleTests {
    @Test func latestNonEmptyNameWins() {
        let lines = jsonLines([
            PiSessionFolderFixture.sessionName("First"),
            PiSessionFolderFixture.sessionName("Second"),
            PiSessionFolderFixture.sessionName("  "),
        ])
        #expect(PiSessionTitle.latestName(amongLines: lines) == "Second")
        #expect(PiSessionTitle.latestName(amongLines: jsonLines([PiSessionFolderFixture.userMessage("Hi")])) == nil)
    }

    @Test func firstUserPromptReadsStringAndPartContent() {
        let stringContent = #"{"type":"message","message":{"role":"user","content":"  Plain prompt  "}}"#
        let assistantFirst = #"{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"Hello"}]}}"#
        let imageThenText = #"{"type":"message","message":{"role":"user","content":[{"type":"image","data":"…"},{"type":"text","text":"Describe it"}]}}"#

        #expect(PiSessionTitle.firstUserPrompt(amongLines: jsonLines([assistantFirst, stringContent])) == "Plain prompt")
        #expect(PiSessionTitle.firstUserPrompt(amongLines: jsonLines([imageThenText])) == "Describe it")
        #expect(PiSessionTitle.firstUserPrompt(amongLines: jsonLines([assistantFirst])) == nil)
    }
}
