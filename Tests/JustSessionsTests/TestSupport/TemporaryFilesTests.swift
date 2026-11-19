import Foundation
import Testing

struct TemporaryFilesTests {
    @Test func aStandInDoesNothingUntilATestRunsIt() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let runsLog = root.appendingPathComponent("runs.log")
        let standIn = try writeTimedStandIn(
            "#!/bin/sh\necho run >> '\(runsLog.path)'\necho \"$1\"\n",
            to: root.appendingPathComponent("cli")
        )

        #expect(!FileManager.default.fileExists(atPath: runsLog.path))

        let result = BoundedProcessRunnerOutput.run(standIn, arguments: ["--version"])

        #expect(result == "--version\n")
        #expect(try String(contentsOf: runsLog, encoding: .utf8) == "run\n")
    }

    @Test func standInsWithTheSameScriptShareOneFileThatRewritingOneLeavesAlone() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let script = "#!/bin/sh\necho \"same $1\"\n"
        let first = try writeExecutableScript(script, to: root.appendingPathComponent("first"))
        let second = try writeExecutableScript(script, to: root.appendingPathComponent("second"))

        #expect(try Self.fileNumber(of: first) == Self.fileNumber(of: second))
        #expect(BoundedProcessRunnerOutput.run(second, arguments: ["run"]) == "same run\n")

        try writeExecutableScript("#!/bin/sh\necho other\n", to: second)

        #expect(try Self.fileNumber(of: first) != Self.fileNumber(of: second))
        #expect(BoundedProcessRunnerOutput.run(first, arguments: ["run"]) == "same run\n")
        #expect(BoundedProcessRunnerOutput.run(second, arguments: []) == "other\n")
    }

    @Test func aRunsCopiesAreRemovedOnceItHasEnded() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let ended = Process()
        ended.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try ended.run()
        ended.waitUntilExit()
        let endedRunsFolder = temporaryDirectory.appendingPathComponent("JustSessionsTests-stand-ins-\(ended.processIdentifier)")
        let runningFolder = temporaryDirectory.appendingPathComponent("JustSessionsTests-stand-ins-1")
        for folder in [endedRunsFolder, runningFolder] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        _ = StandInScripts(temporaryDirectory: temporaryDirectory)

        #expect(!FileManager.default.fileExists(atPath: endedRunsFolder.path))
        #expect(FileManager.default.fileExists(atPath: runningFolder.path))
    }

    private static func fileNumber(of file: URL) throws -> Int {
        try #require(FileManager.default.attributesOfItem(atPath: file.path)[.systemFileNumber] as? Int)
    }
}

private enum BoundedProcessRunnerOutput {
    static func run(_ executable: URL, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
}
