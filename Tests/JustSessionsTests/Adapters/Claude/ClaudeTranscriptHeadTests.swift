import Foundation
import Testing
@testable import JustSessions

struct ClaudeTranscriptHeadTests {
    @Test func readsTheFirstWorkingDirectoryTheFirstPromptAndACustomTitle() {
        let head = ClaudeTranscriptHead(lines: jsonLines([
            #"{"type":"summary","summary":"Earlier work"}"#,
            #"{"type":"user","cwd":"/Users/me/app","message":{"content":[{"type":"tool_result","content":"ok"}]}}"#,
            #"{"type":"user","cwd":"/Users/me/app/Sources","message":{"content":"Fix the build"}}"#,
            #"{"type":"custom-title","customTitle":"Build fixes"}"#,
        ]))

        #expect(head.workingDirectory == "/Users/me/app")
        #expect(head.firstPrompt == "Fix the build")
        #expect(head.customTitle == "Build fixes")
        #expect(!head.isSidechain)
    }

    /// A prompt sent with a screenshot has its text and the image as parts, and the text is what was typed.
    @Test func aPromptSentWithImagesIsItsTextPart() {
        let head = ClaudeTranscriptHead(lines: jsonLines([
            #"{"type":"user","message":{"content":[{"type":"image","source":{"data":"iVBORw0"}},{"type":"text","text":"[Image #1] What is this?"}]}}"#,
            #"{"type":"user","message":{"content":"Fix the build"}}"#,
        ]))

        #expect(head.firstPrompt == "[Image #1] What is this?")
    }

    /// Claude Code writes a few bookkeeping lines before the first prompt, none naming the folder, so a first
    /// prompt sent with screenshots, hundreds of kilobytes of image data, must still be read whole.
    @Test func aFirstPromptLongerThanAnOldLimitIsStillRead() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: file) }
        let imageData = String(repeating: "A", count: 300_000)
        try [
            #"{"type":"mode","mode":"normal"}"#,
            #"{"type":"permission-mode","permissionMode":"auto"}"#,
            #"{"type":"user","cwd":"/Users/me/app","message":{"content":[{"type":"text","text":"What is this?"},{"type":"image","source":{"data":"\#(imageData)"}}]}}"#,
            #"{"type":"assistant","cwd":"/Users/me/app","message":{"content":[{"type":"text","text":"A chart."}]}}"#,
        ].joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)

        let head = ClaudeTranscriptHead(file: file)

        #expect(head.workingDirectory == "/Users/me/app")
        #expect(head.firstPrompt == "What is this?")
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
