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

        #expect(BoundedProcessRunner.result(ofExecutable: "/bin/sleep", arguments: ["600"], timeout: 0.3) == nil)
        // Well short of the 600 seconds `sleep` runs, so the timeout, not the process ending, stopped the wait.
        #expect(clock.now - startedAt < .seconds(120))
    }

    @Test func aTimedOutWrapperCannotLeaveAChildWritingAfterTheResult() throws {
        let folder = try makeTemporaryDirectory()
        defer { Self.cleanUpDelayedChild(in: folder) }
        let marker = folder.appendingPathComponent("late-write")
        let result = BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", Self.delayedChildScript],
            workingDirectory: folder,
            timeout: 0.15
        )
        #expect(result == nil)
        try Data().write(to: folder.appendingPathComponent("release"))
        Thread.sleep(forTimeInterval: 0.8)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func cancelingAnOptedInTaskStopsItsWrapperAndChildren() async throws {
        let folder = try makeTemporaryDirectory()
        defer { Self.cleanUpDelayedChild(in: folder) }
        let started = folder.appendingPathComponent("started")
        let marker = folder.appendingPathComponent("late-write")
        let task = Task.detached {
            BoundedProcessRunner.result(
                ofExecutable: "/bin/sh",
                arguments: ["-c", Self.delayedChildScript],
                workingDirectory: folder,
                timeout: 30,
                cancelsWithTask: true
            )
        }
        defer { task.cancel() }
        let deadline = ContinuousClock.now + .seconds(10)
        while !FileManager.default.fileExists(atPath: started.path), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(FileManager.default.fileExists(atPath: started.path))
        task.cancel()
        #expect(await task.value == nil)
        try Data().write(to: folder.appendingPathComponent("release"))
        try await Task.sleep(for: .milliseconds(800))
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    // The side effect is released only AFTER the helper reports timeout/cancellation, so a busy test machine
    // cannot let the child write before the test gets a chance to cancel it.
    private static let delayedChildScript = """
        (while [ ! -e release ]; do sleep 0.01; done; touch late-write) &
        echo $! > child-id
        touch started
        wait
        """

    private static func cleanUpDelayedChild(in folder: URL) {
        if let text = try? String(contentsOf: folder.appendingPathComponent("child-id"), encoding: .utf8),
           let childID = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(childID, SIGKILL)
        }
        try? FileManager.default.removeItem(at: folder)
    }

    /// A pipe would stay open while the child it leaves behind runs; output in a file does not wait for it.
    @Test func aChildLeftRunningDoesNotHoldUpTheResult() throws {
        let clock = ContinuousClock()
        let startedAt = clock.now

        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "/bin/sleep 600 & echo $!"],
            timeout: 120
        ))
        let childProcessID = try #require(pid_t(output.trimmingCharacters(in: .whitespacesAndNewlines)))
        kill(childProcessID, SIGKILL)

        // Well short of the child's 600 seconds, so the result came back without waiting for it.
        #expect(clock.now - startedAt < .seconds(120))
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
