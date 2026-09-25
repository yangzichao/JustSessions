import Darwin
import Foundation
import Testing
@testable import JustSessions

struct ProcessOpenFileReaderTests {
    @Test func groupsFilesByProcessInLsofFieldOutput() {
        let output = """
        p93163
        fcwd
        n/Users/example/workplace/project
        f65
        n/Users/example/.codex/sessions/2026/09/24/rollout-2026-09-24T07-28-33-01a0d3d1-6f20-7f03-a220-642217461510.jsonl
        p93170
        f3
        n/tmp/other
        """

        #expect(ProcessOpenFileReader.openFilePaths(inLsofFieldOutput: output) == [
            93163: [
                "/Users/example/workplace/project",
                "/Users/example/.codex/sessions/2026/09/24/rollout-2026-09-24T07-28-33-01a0d3d1-6f20-7f03-a220-642217461510.jsonl",
            ],
            93170: ["/tmp/other"],
        ])
    }

    @Test func listsAFileThisProcessHoldsOpenAndSkipsProcessesThatAreGone() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("open-file-\(UUID().uuidString).jsonl")
        try "{}\n".write(to: file, atomically: true, encoding: .utf8)
        let openFile = try FileHandle(forReadingFrom: file)
        defer {
            try? openFile.close()
            try? FileManager.default.removeItem(at: file)
        }

        let openFilePaths = ProcessOpenFileReader().openFilePaths(ofProcessIDs: [999_999, getpid()])

        #expect(openFilePaths[getpid()]?.contains { $0.hasSuffix("/\(file.lastPathComponent)") } == true)
        #expect(openFilePaths[999_999] == nil)
    }
}
