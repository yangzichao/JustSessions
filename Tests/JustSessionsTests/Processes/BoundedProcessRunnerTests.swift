import Darwin
import Foundation
import Testing
@testable import JustSessions

struct BoundedProcessRunnerTests {
    @Test func returnsTheExitStatusAndOnlyTheOutputAskedFor() throws {
        let script = "echo out; echo err >&2; exit 3"

        let standardOutputOnly = try #require(BoundedProcessRunner.result(ofExecutable: "/bin/sh", arguments: ["-c", script], timeout: 5))
        let bothStreams = try #require(BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", script],
            includesStandardError: true,
            timeout: 5
        ))

        #expect(standardOutputOnly.exitStatus == 3)
        #expect(standardOutputOnly.output == "out\n")
        #expect(bothStreams.exitStatus == 3)
        #expect(bothStreams.output.split(separator: "\n").sorted() == ["err", "out"])
    }

    @Test func runsInTheGivenFolder() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }

        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "pwd -P"],
            workingDirectory: folder,
            timeout: 5
        ))

        let workingDirectory = output.trimmingCharacters(in: .newlines)
        #expect(URL(fileURLWithPath: workingDirectory).resolvingSymlinksInPath() == folder.resolvingSymlinksInPath())
    }

    @Test func passesTheGivenEnvironmentInsteadOfItsOwn() throws {
        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/usr/bin/env",
            arguments: [],
            environment: ["JUSTSESSIONS_TEST_VARIABLE": "passed"],
            timeout: 5
        ))

        let variableNames = output.split(separator: "\n").map { $0.prefix { $0 != "=" } }
        #expect(output.contains("JUSTSESSIONS_TEST_VARIABLE=passed\n"))
        #expect(!variableNames.contains("HOME"))
        #expect(!variableNames.contains("PATH"))
    }

    @Test func stopsAProcessThatRunsTooLong() {
        let clock = ContinuousClock()
        let startedAt = clock.now

        #expect(BoundedProcessRunner.result(ofExecutable: "/bin/sleep", arguments: ["30"], timeout: 0.3) == nil)
        #expect(clock.now - startedAt < .seconds(5))
    }

    /// A pipe would stay open while the child it leaves behind runs; output in a file does not wait for it.
    @Test func aChildLeftRunningDoesNotHoldUpTheResult() throws {
        let clock = ContinuousClock()
        let startedAt = clock.now

        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "/bin/sleep 30 & echo $!"],
            timeout: 10
        ))
        let childProcessID = try #require(pid_t(output.trimmingCharacters(in: .whitespacesAndNewlines)))
        kill(childProcessID, SIGKILL)

        #expect(clock.now - startedAt < .seconds(5))
    }

    /// A pipe holds 64 KB; a process that writes more than that into an unread pipe stalls until the timeout.
    @Test func moreOutputThanAPipeHoldsComesBackWhole() throws {
        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "/usr/bin/head -c 1000000 /dev/zero | /usr/bin/tr '\\0' x"],
            timeout: 10
        ))

        #expect(output.utf8.count == 1_000_000)
        #expect(output.allSatisfy { $0 == "x" })
    }

    @Test func anExecutableThatCannotStartGivesNoResult() throws {
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let notExecutable = folder.appendingPathComponent("tool")
        try "#!/bin/sh\necho hi\n".write(to: notExecutable, atomically: true, encoding: .utf8)

        #expect(BoundedProcessRunner.result(ofExecutable: folder.appendingPathComponent("missing").path, arguments: [], timeout: 5) == nil)
        #expect(BoundedProcessRunner.result(ofExecutable: notExecutable.path, arguments: [], timeout: 5) == nil)
    }

    @Test func outputThatIsNotUTF8IsStillReturned() throws {
        let output = try #require(BoundedProcessRunner.output(ofExecutable: "/usr/bin/printf", arguments: ["ok\\377"], timeout: 5))
        #expect(output == "ok\u{FFFD}")
    }
}
