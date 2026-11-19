import Foundation
import Testing

@testable import JustSessions

struct RemoteSignInOutputTests {
    private func output(_ chunks: String...) -> RemoteSignInOutput {
        var output = RemoteSignInOutput()
        for chunk in chunks { output.append(Data(chunk.utf8)) }
        return output
    }

    @Test func theLineItWaitsAfterIsTheQuestionAndTheLinesBeforeItItsContext() {
        let printed = output("\u{1B}[1mSigning in\u{1B}[0m as me\r\n\r\n", "Your token expired.\r\nPIN: ")

        #expect(printed.question == "PIN:")
        #expect(printed.endsMidLine)
        #expect(printed.context == "Signing in as me\nYour token expired.")
    }

    @Test func aQuestionOnALineOfItsOwnIsStillTheLastLine() {
        let printed = output("Press your key to type its code\r\n")

        #expect(printed.question == "Press your key to type its code")
        #expect(!printed.endsMidLine)
        #expect(printed.context == nil)
    }

    @Test func theTerminalsEchoOfAnAnswerIsLeftOut() {
        var printed = output("PIN: ")
        printed.noteAnswered("1234")
        printed.append(Data("12".utf8))
        printed.append(Data("34\r\nCode: ".utf8))

        #expect(printed.question == "Code:")
        #expect(printed.context == nil)
        #expect(!(printed.failureText ?? "").contains("1234"))
    }

    @Test func outputThatOnlyStartsLikeTheAnswerIsKept() {
        var printed = output("Code: ")
        printed.noteAnswered("12")
        printed.append(Data("\r\n1 attempt left\r\nCode: ".utf8))

        #expect(printed.context == "1 attempt left")
        #expect(printed.question == "Code:")
    }

    @Test func aCharacterSplitBetweenReadsArrivesWhole() {
        let bytes = Array("Clé PIN: ".utf8)
        var printed = RemoteSignInOutput()
        printed.append(Data(bytes[0..<3]))
        printed.append(Data(bytes[3...]))

        #expect(printed.question == "Clé PIN:")
    }

    @Test func titlesAndBackspacesLeaveNothingBehind() {
        let printed = output("\u{1B}]0;host: signing in\u{07}Passwordx\u{08}: ")

        #expect(printed.question == "Password:")
    }

    @Test func aFailureKeepsTheLastLinesOfTheWholeRun() {
        var printed = output((1...12).map { "line \($0)\r\n" }.joined())
        printed.noteAnswered("secret")
        printed.append(Data("\r\nToken expired\r\n".utf8))

        #expect(printed.failureText == (6...12).map { "line \($0)" }.joined(separator: "\n") + "\nToken expired")
    }
}
