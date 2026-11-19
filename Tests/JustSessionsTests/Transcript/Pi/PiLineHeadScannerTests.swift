import Foundation
import Testing

@testable import JustSessions

struct PiLineHeadScannerTests {
    @Test func skipsExactTextAndStaysPutOtherwise() {
        var scanner = PiLineHeadScanner(line: Data(#"{"type":"message"}"#.utf8), byteLimit: 512)

        let skippedOtherKey = scanner.skip(#"{"kind":"#)
        let skippedPastTheEnd = scanner.skip(#"{"type":"message"},"#)
        let positionAfterMisses = scanner.position
        let skippedKey = scanner.skip(#"{"type":""#)
        let value = scanner.plainString()
        let skippedBrace = scanner.skip("}")
        let skippedBeyondTheLine = scanner.skip("}")

        #expect(!skippedOtherKey)
        #expect(!skippedPastTheEnd)
        #expect(positionAfterMisses == 0)
        #expect(skippedKey)
        #expect(value == "message")
        #expect(skippedBrace)
        #expect(!skippedBeyondTheLine)
    }

    @Test func aStringWithAnEscapeOrCutOffByTheLimitIsNotRead() {
        var escaped = PiLineHeadScanner(line: Data(#""a\u0032","#.utf8), byteLimit: 512)
        var cutOff = PiLineHeadScanner(line: Data(#""message","#.utf8), byteLimit: 8)

        let escapedValue = escaped.skip("\"") ? escaped.plainString() : "not skipped"
        let cutOffValue = cutOff.skip("\"") ? cutOff.plainString() : "not skipped"
        let skippedPastTheLimit = cutOff.skip("message\"")

        #expect(escapedValue == nil)
        #expect(escaped.position == 1)
        #expect(cutOffValue == nil)
        #expect(!skippedPastTheLimit)
    }

    @Test func readsALineSlicedFromALargerBufferFromItsOwnStart() {
        let buffer = Data((String(repeating: "x", count: 600) + "\n" + #"{"type":"message","id":"a1"}"#).utf8)
        let line = buffer[601...]
        var scanner = PiLineHeadScanner(line: line, byteLimit: 26)

        let skippedType = scanner.skip(#"{"type":""#)
        let entryType = scanner.plainString()
        let skippedID = scanner.skip(#","id":""#)
        let id = scanner.plainString()

        #expect(skippedType)
        #expect(entryType == "message")
        #expect(skippedID)
        #expect(id == nil)
        #expect(scanner.position == line.startIndex + 24)
    }
}
