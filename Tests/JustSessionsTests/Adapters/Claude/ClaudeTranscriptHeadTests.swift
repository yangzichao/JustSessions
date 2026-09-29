import Foundation
import Testing
@testable import JustSessions

struct ClaudeTranscriptHeadTests {
    @Test func readsTheFirstWorkingDirectoryTheFirstPlainTextPromptAndACustomTitle() {
        let head = ClaudeTranscriptHead(lines: jsonLines([
            #"{"type":"summary","summary":"Earlier work"}"#,
            #"{"type":"user","cwd":"/Users/me/app","message":{"content":[{"type":"text","text":"Sent as parts"}]}}"#,
            #"{"type":"user","cwd":"/Users/me/app/Sources","message":{"content":"Fix the build"}}"#,
            #"{"type":"custom-title","customTitle":"Build fixes"}"#,
        ]))

        #expect(head.workingDirectory == "/Users/me/app")
        #expect(head.firstPrompt == "Fix the build")
        #expect(head.customTitle == "Build fixes")
        #expect(!head.isSidechain)
    }

    @Test func anySidechainLineMarksTheSession() {
        let head = ClaudeTranscriptHead(lines: jsonLines([
            #"{"type":"user","isSidechain":false,"message":{"content":"Look into it"}}"#,
            #"{"type":"assistant","isSidechain":true}"#,
        ]))

        #expect(head.isSidechain)
    }

    @Test func linesPastTheLineLimitAreNotRead() {
        let filler = Array(repeating: #"{"type":"assistant"}"#, count: ClaudeTranscriptHead.maximumLineCount - 1)
        let prompt = #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Fix the build"}}"#

        #expect(ClaudeTranscriptHead(lines: jsonLines(filler + [prompt])).firstPrompt == "Fix the build")
        #expect(ClaudeTranscriptHead(lines: jsonLines(filler + [#"{"type":"assistant"}"#, prompt])).firstPrompt == nil)
    }

    @Test func linesThatAreNotJSONObjectsAreSkipped() {
        let head = ClaudeTranscriptHead(lines: jsonLines([
            "not json",
            "[1, 2]",
            #"{"type":"user","cwd":"/Users/me/app","message":{"content":"Fix the build"}}"#,
        ]))

        #expect(head.workingDirectory == "/Users/me/app")
        #expect(head.firstPrompt == "Fix the build")
    }

    @Test func aMissingFileSaysNothing() {
        let head = ClaudeTranscriptHead(file: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jsonl"))

        #expect(head.workingDirectory == nil)
        #expect(head.firstPrompt == nil)
        #expect(head.customTitle == nil)
        #expect(!head.isSidechain)
    }
}
