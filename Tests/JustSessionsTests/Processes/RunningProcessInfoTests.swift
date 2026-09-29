import Darwin
import Foundation
import Testing
@testable import JustSessions

struct RunningProcessInfoTests {
    @Test func tellsWhenARunningProcessStarted() throws {
        let processID = getpid()

        #expect(RunningProcessInfo.isRunning(processID))
        let startDate = try #require(RunningProcessInfo.startDate(of: processID))
        let oneDayAgo = Date.now.addingTimeInterval(-24 * 60 * 60)
        #expect(startDate <= .now)
        #expect(startDate > oneDayAgo)
    }

    @Test func countsAProcessThisAppMayNotSignal() {
        // launchd belongs to root.
        #expect(RunningProcessInfo.isRunning(1))
    }

    @Test func aProcessThatEndedIsNotRunning() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()

        #expect(!RunningProcessInfo.isRunning(process.processIdentifier))
        #expect(RunningProcessInfo.startDate(of: process.processIdentifier) == nil)
    }

    @Test func noProcessIDIsNoProcess() {
        #expect(!RunningProcessInfo.isRunning(0))
        #expect(!RunningProcessInfo.isRunning(-1))
        #expect(RunningProcessInfo.startDate(of: 0) == nil)
    }
}
