import Foundation
import Testing

@testable import JustSessions

struct ShellQuotingPropertyTests {
    struct Shell: Sendable, CustomTestStringConvertible {
        let executablePath: String
        let options: [String]
        var testDescription: String { executablePath }
    }

    private static let awkwardCharacters: [Character] = [
        "'", "'", "\"", "\\", "$", "`", " ", "\n", "\t", "\r", ";", "&", "|", "*", "?", "!", "#", "~",
        "(", ")", "{", "}", "[", "]", "<", ">", "%", "=", "-", "a", "Z", "0", "é", "中", "🚀",
    ]

    @Test(arguments: [
        Shell(executablePath: "/bin/sh", options: []),
        Shell(executablePath: "/bin/bash", options: []),
        Shell(executablePath: "/bin/zsh", options: ["-f"]),
    ])
    func quotedValuesReachTheCommandUnchanged(in shell: Shell) throws {
        var generator = SeededRandomNumberGenerator(seed: 0x5E11)
        let values = [""] + (0..<300).map { _ in generator.string(of: Self.awkwardCharacters, lengthIn: 0...12) }

        let output = try #require(Self.printEachValue(values, in: shell))

        #expect(Self.nulTerminatedValues(output) == values)
    }

    @Test func valuesQuotedTwiceSurviveAShellInsideAShell() throws {
        var generator = SeededRandomNumberGenerator(seed: 0xD0B1E)
        let values = (0..<100).map { _ in generator.string(of: Self.awkwardCharacters, lengthIn: 1...8) }
        let innerScript = "printf '%s\\0' " + values.map(ShellQuoting.quoted).joined(separator: " ")

        let output = try #require(
            BoundedProcessRunner.output(
                ofExecutable: "/bin/sh",
                arguments: ["-c", "/bin/sh -c " + ShellQuoting.quoted(innerScript)],
                environment: ["PATH": "/usr/bin:/bin"],
                timeout: 10
            ))

        #expect(Self.nulTerminatedValues(output) == values)
    }

    @Test func singleQuotesAndBackslashesAreWrittenOutsideTheQuotes() {
        #expect(ShellQuoting.quoted("it's") == #"'it'\''s'"#)
        #expect(ShellQuoting.quoted(#"a\b"#) == #"'a'\\'b'"#)
        #expect(ShellQuoting.quoted("") == "''")
        #expect(ShellQuoting.quoted("$HOME") == "'$HOME'")
    }

    /// A fish login shell reads `\'` and `\\` inside single quotes as escapes, so a value quoted once or twice must
    /// keep backslashes out of them, where fish and POSIX shells read `\'` and `\\` alike.
    @Test func quotingOnceOrTwiceLeavesNoBackslashInsideSingleQuotes() {
        var generator = SeededRandomNumberGenerator(seed: 0xF15B)
        for value in (0..<300).map({ _ in generator.string(of: Self.awkwardCharacters, lengthIn: 0...12) }) {
            let once = ShellQuoting.quoted(value)
            #expect(Self.hasNoBackslashInsideSingleQuotes(once), "\(once)")
            #expect(Self.hasNoBackslashInsideSingleQuotes(ShellQuoting.quoted("sh -c " + once)), "\(value)")
        }
    }

    /// Outside single quotes, a backslash escapes the next character; inside them, there is none.
    private static func hasNoBackslashInsideSingleQuotes(_ word: String) -> Bool {
        var isInsideQuotes = false
        var characters = word.makeIterator()
        while let character = characters.next() {
            switch (character, isInsideQuotes) {
            case ("'", _): isInsideQuotes.toggle()
            case ("\\", true): return false
            case ("\\", false): _ = characters.next()
            default: break
            }
        }
        return !isInsideQuotes
    }

    private static func printEachValue(_ values: [String], in shell: Shell) -> String? {
        BoundedProcessRunner.output(
            ofExecutable: shell.executablePath,
            arguments: shell.options + ["-c", "printf '%s\\0' " + values.map(ShellQuoting.quoted).joined(separator: " ")],
            environment: ["PATH": "/usr/bin:/bin"],
            timeout: 10
        )
    }

    private static func nulTerminatedValues(_ output: String) -> [String] {
        var values = Data(output.utf8).split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
        values.removeLast()
        return values
    }
}
