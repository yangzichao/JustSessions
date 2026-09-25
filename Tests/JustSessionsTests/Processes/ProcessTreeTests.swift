import Darwin
import Foundation
import Testing
@testable import JustSessions

struct ProcessTreeTests {
    @Test func listsTheRootThenEveryDescendantButNoOtherProcess() {
        let tree = ProcessTree(parentProcessIDs: [
            100: 1,
            200: 100,
            201: 100,
            300: 200,
            400: 1,
        ])

        #expect(tree.processIDs(rootedAt: 100) == [100, 200, 201, 300])
        #expect(tree.processIDs(rootedAt: 12_345) == [12_345])
    }

    @Test func findsTheChildThatARunningWrapperStarted() throws {
        // `sh` stands in for a wrapper script that starts the real CLI as a child process.
        let wrapper = Process()
        wrapper.executableURL = URL(fileURLWithPath: "/bin/sh")
        wrapper.arguments = ["-c", "sleep 30 & echo $!; wait"]
        let output = Pipe()
        wrapper.standardOutput = output
        try wrapper.run()
        let childLine = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self)
        let childProcessID = try #require(Int32(childLine.trimmingCharacters(in: .whitespacesAndNewlines)))
        defer {
            kill(childProcessID, SIGKILL)
            wrapper.waitUntilExit()
        }

        let processIDs = ProcessTree.ofRunningProcesses().processIDs(rootedAt: wrapper.processIdentifier)

        #expect(processIDs.first == wrapper.processIdentifier)
        #expect(processIDs.contains(childProcessID))
    }
}
