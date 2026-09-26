import Foundation
import Testing
@testable import JustSessions

/// Paths, session ids, and scripts reach SSH hosts inside quoted shell words. Whatever a value holds, the command
/// it is passed to receives exactly that value.
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

    /// Like the command a tab runs on an SSH host: a script quoted once more and handed to another shell.
    @Test func valuesQuotedTwiceSurviveAShellInsideAShell() throws {
        var generator = SeededRandomNumberGenerator(seed: 0xD0B1E)
        let values = (0..<100).map { _ in generator.string(of: Self.awkwardCharacters, lengthIn: 1...8) }
        let innerScript = "printf '%s\\0' " + values.map(ShellQuoting.quoted).joined(separator: " ")

        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "/bin/sh -c " + ShellQuoting.quoted(innerScript)],
            environment: ["PATH": "/usr/bin:/bin"],
            timeout: 10
        ))

        #expect(Self.nulTerminatedValues(output) == values)
    }

    @Test func singleQuotesAreClosedEscapedAndReopened() {
        #expect(ShellQuoting.quoted("it's") == #"'it'\''s'"#)
        #expect(ShellQuoting.quoted("") == "''")
        #expect(ShellQuoting.quoted("$HOME") == "'$HOME'")
    }

    private static func printEachValue(_ values: [String], in shell: Shell) -> String? {
        BoundedProcessRunner.output(
            ofExecutable: shell.executablePath,
            arguments: shell.options + ["-c", "printf '%s\\0' " + values.map(ShellQuoting.quoted).joined(separator: " ")],
            environment: ["PATH": "/usr/bin:/bin"],
            timeout: 10
        )
    }

    /// Splits at the NUL bytes `printf '%s\0'` writes after each value; split as bytes, since a `\r` at the end of
    /// one value would otherwise join the next separator into one `Character`.
    private static func nulTerminatedValues(_ output: String) -> [String] {
        var values = Data(output.utf8).split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
        values.removeLast()
        return values
    }
}
