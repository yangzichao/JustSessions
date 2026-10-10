import Foundation
import Testing
@testable import JustSessions

struct RemoteSSHFolderOpenerTests {
    @Test func passesTheFolderURIToTheTool() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let argumentsFile = directory.appendingPathComponent("arguments")
        let tool = try writeExecutableScript(
            "#!/bin/sh\nprintf '%s\\n' \"$@\" > '\(argumentsFile.path)'\n",
            to: directory.appendingPathComponent("code")
        )

        try await RemoteSSHFolderOpener.open(path: "/srv/my app", on: "devbox", withCommandLineToolAt: tool)

        #expect(try String(contentsOf: argumentsFile, encoding: .utf8)
            == "--folder-uri\nvscode-remote://ssh-remote+devbox/srv/my%20app\n")
    }

    @Test func reportsWhatAFailingToolPrinted() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let tool = try writeExecutableScript(
            "#!/bin/sh\necho 'cannot open window' >&2\nexit 1\n",
            to: directory.appendingPathComponent("code")
        )

        await #expect(throws: RemoteSSHFolderOpenError.failed("cannot open window")) {
            try await RemoteSSHFolderOpener.open(path: "/srv/app", on: "devbox", withCommandLineToolAt: tool)
        }
    }
}
