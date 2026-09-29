import Foundation
import Testing
@testable import JustSessions

struct ConversationMetadataTests {
    struct TitleCase: Sendable, CustomTestStringConvertible {
        let rawTitle: String?
        let expectedTitle: String
        let testDescription: String
    }

    static let titleCases = [
        TitleCase(rawTitle: nil, expectedTitle: "Fallback", testDescription: "no prompt"),
        TitleCase(rawTitle: "", expectedTitle: "Fallback", testDescription: "empty prompt"),
        TitleCase(rawTitle: " \n\t ", expectedTitle: "Fallback", testDescription: "blank prompt"),
        TitleCase(rawTitle: "<command-name>/clear</command-name>", expectedTitle: "Fallback", testDescription: "injected markup"),
        TitleCase(rawTitle: "\n<local-command-stdout>ok</local-command-stdout>", expectedTitle: "Fallback", testDescription: "markup after a blank line"),
        TitleCase(rawTitle: "  Fix the build  ", expectedTitle: "Fix the build", testDescription: "padded prompt"),
        TitleCase(rawTitle: "First line\nSecond line", expectedTitle: "First line", testDescription: "several lines"),
        TitleCase(rawTitle: "Windows line\r\nnext", expectedTitle: "Windows line", testDescription: "CRLF line ending"),
        TitleCase(rawTitle: "\n\n  Pasted after blank lines", expectedTitle: "Pasted after blank lines", testDescription: "leading blank lines"),
        TitleCase(rawTitle: "Compare a < b", expectedTitle: "Compare a < b", testDescription: "angle bracket inside the text"),
        TitleCase(
            rawTitle: String(repeating: "é", count: 200),
            expectedTitle: String(repeating: "é", count: ConversationMetadata.maximumTitleLength),
            testDescription: "long prompt"
        ),
    ]

    @Test(arguments: titleCases)
    func titleIsTheFirstLineTheUserTyped(_ titleCase: TitleCase) {
        #expect(ConversationMetadata.cleanTitle(titleCase.rawTitle, fallback: "Fallback") == titleCase.expectedTitle)
    }

    @Test(arguments: [
        "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
        "3f2504e0-4f89-11d3-9a0c-0305e82c3301",
    ])
    func sessionIDsAreUUIDsInEitherCase(_ sessionID: String) {
        #expect(ConversationMetadata.isValidSessionID(sessionID))
    }

    /// Session ids end up in file paths and in commands run on SSH hosts, so nothing but a UUID gets through.
    @Test(arguments: [
        "",
        "not-a-uuid",
        "3F2504E04F8911D39A0C0305E82C3301",
        "{3F2504E0-4F89-11D3-9A0C-0305E82C3301}",
        "3F2504E0-4F89-11D3-9A0C-0305E82C330",
        "../3F2504E0-4F89-11D3-9A0C-0305E82C3301",
        "3F2504E0-4F89-11D3-9A0C-0305E82C3301; rm -rf ~",
        "3F2504E0-4F89-11D3-9A0C-0305E82C3301\n",
    ])
    func anythingElseIsNotASessionID(_ sessionID: String) {
        #expect(!ConversationMetadata.isValidSessionID(sessionID))
    }

    struct TimestampCase: Sendable, CustomTestStringConvertible {
        let text: String
        let expectedSecondsSince1970: Double?
        var testDescription: String { text.isEmpty ? "(empty)" : text }
    }

    static let timestampCases = [
        TimestampCase(text: "2026-09-24T10:00:00Z", expectedSecondsSince1970: 1_790_244_000),
        TimestampCase(text: "2026-09-24T10:00:00.123Z", expectedSecondsSince1970: 1_790_244_000.123),
        TimestampCase(text: "2026-09-24T12:00:00+02:00", expectedSecondsSince1970: 1_790_244_000),
        TimestampCase(text: "2026-09-24T03:00:00.5-07:00", expectedSecondsSince1970: 1_790_244_000.5),
        TimestampCase(text: "2026-09-24 10:00:00Z", expectedSecondsSince1970: nil),
        TimestampCase(text: "2026-09-24T10:00:00", expectedSecondsSince1970: nil),
        TimestampCase(text: "yesterday", expectedSecondsSince1970: nil),
        TimestampCase(text: "", expectedSecondsSince1970: nil),
    ]

    @Test(arguments: timestampCases)
    func timestampsWithAndWithoutFractionalSecondsParse(_ timestampCase: TimestampCase) throws {
        let parsedSeconds = ConversationMetadata.date(timestampCase.text)?.timeIntervalSince1970
        if let expectedSeconds = timestampCase.expectedSecondsSince1970 {
            let seconds = try #require(parsedSeconds)
            #expect(abs(seconds - expectedSeconds) < 0.000_5)
        } else {
            #expect(parsedSeconds == nil)
        }
    }

    @Test func onlyTextIsReadAsATimestamp() {
        #expect(ConversationMetadata.date(nil) == nil)
        #expect(ConversationMetadata.date(1_790_244_000) == nil)
        #expect(ConversationMetadata.date(["2026-09-24T10:00:00Z"]) == nil)
    }

    @Test func firstLineIsReadOnlyWhenItIsAWholeJSONObject() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        func firstLine(of contents: String, maxBytes: Int = 65_536) throws -> [String: Any]? {
            let file = root.appendingPathComponent("\(UUID().uuidString).jsonl")
            try contents.write(to: file, atomically: true, encoding: .utf8)
            return ConversationMetadata.firstLine(of: file, maxBytes: maxBytes)
        }

        #expect(try firstLine(of: "{\"id\":\"abc\"}\n{\"id\":\"second\"}\n")?["id"] as? String == "abc")
        #expect(try firstLine(of: "") == nil)
        #expect(try firstLine(of: "\n{\"id\":\"second\"}\n") == nil)
        #expect(try firstLine(of: "[1, 2]\n") == nil)
        #expect(try firstLine(of: "{\"id\":\"cut off") == nil)
        #expect(try firstLine(of: "{\"id\":\"longer than the limit\"}\n", maxBytes: 8) == nil)
        #expect(ConversationMetadata.firstLine(of: root.appendingPathComponent("missing.jsonl")) == nil)
    }
}
