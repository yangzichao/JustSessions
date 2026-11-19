import Foundation
import Testing

@testable import JustSessions

/// The lock Kiro CLI writes while a CLI runs a session, in the two shapes 2.16.2 and 2.34.0 wrote on this Mac.
struct KiroSessionLockTests {
    /// `{"pid":…,"started_at":"…"}`, as Kiro writes it; `fractionalDigits` 6 as V2 writes it, 3 as V3 does.
    static func writeLock(processID: Int32, startedAt: Date, fractionalDigits: Int = 6, to file: URL) throws {
        let formatter = ISO8601DateFormatter()
        let seconds = formatter.string(from: startedAt).dropLast()
        let text = "{\"pid\":\(processID),\"started_at\":\"\(seconds).\(String(repeating: "4", count: fractionalDigits))Z\"}"
        try text.write(to: file, atomically: true, encoding: .utf8)
    }

    static func endedProcessID() throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }

    @Test func theLockSitsBesideAV2SessionAndInAV3SessionsFolder() {
        let v2 = URL(fileURLWithPath: "/k/.kiro/sessions/cli/a117957d-44d3-4375-b552-4373d8e5e74a.jsonl")
        let v3 = URL(fileURLWithPath: "/k/.kiro/sessions/d0ea1a8bdee5da32/sess_f9ea81c4-e3be-407b-8779-6aeeb1646cef/messages.jsonl")

        #expect(KiroSessionLock.file(forSessionFile: v2).path == "/k/.kiro/sessions/cli/a117957d-44d3-4375-b552-4373d8e5e74a.lock")
        #expect(
            KiroSessionLock.file(forSessionFile: v3).path
                == "/k/.kiro/sessions/d0ea1a8bdee5da32/sess_f9ea81c4-e3be-407b-8779-6aeeb1646cef/.lock")
    }

    @Test(arguments: [6, 3])
    func readsTheProcessAndWhenItTookTheLock(fractionalDigits: Int) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("x.lock")
        let startedAt = Date(timeIntervalSince1970: 1_792_798_000)
        try Self.writeLock(processID: 73741, startedAt: startedAt, fractionalDigits: fractionalDigits, to: file)

        #expect(KiroSessionLock(file: file) == KiroSessionLock(processID: 73741, startedAt: startedAt))
    }

    @Test(arguments: ["", "{}", "{\"pid\":\"73741\"}", "{\"pid\":1}", "not json", String(repeating: " ", count: 5_000) + "{\"pid\":73741}"])
    func aLockWithoutAUsableProcessIsNone(_ text: String) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("x.lock")
        try text.write(to: file, atomically: true, encoding: .utf8)

        #expect(KiroSessionLock(file: file) == nil)
        #expect(KiroSessionLock(file: directory.appendingPathComponent("missing.lock")) == nil)
    }

    @Test func onlyARunningProcessThatStartedBeforeTheLockHoldsIt() throws {
        let running = getpid()

        #expect(KiroSessionLock(processID: running, startedAt: .now).isHeld)
        #expect(KiroSessionLock(processID: running, startedAt: nil).isHeld)
        #expect(!KiroSessionLock(processID: running, startedAt: Date(timeIntervalSince1970: 1_000_000_000)).isHeld)
        #expect(!KiroSessionLock(processID: try Self.endedProcessID(), startedAt: .now).isHeld)
    }
}

struct LostKiroCLIsTests {
    let lostName = LostKiroCLIs.temporaryNamePrefix + "33825d05"

    @Test func onlyTemporaryKiroNamesNoTabShowsAreLost() {
        let shownName = LostKiroCLIs.temporaryNamePrefix + "0a0a0a0a"
        let panes: [String: Int32] = [
            lostName: 100, shownName: 200,
            TmuxSessionName.forSession(provider: .kiro, sessionID: UUID().uuidString.lowercased()): 300,
            TmuxSessionName.unique(for: .claude): 400,
        ]

        #expect(LostKiroCLIs.lostPaneProcessIDs(in: panes, tabTmuxNames: [shownName]) == [lostName: 100])
    }

    /// Kiro CLI 2.16.2's V2 lock names `kiro-cli-chat acp`, three processes below the pane's `kiro-cli`.
    @Test func aLockBelowAPaneNamesItsSession() {
        let tree = ProcessTree(parentProcessIDs: [100: 50, 101: 100, 102: 101, 103: 102, 900: 1])

        let matches = LostKiroCLIs.sessionIDs(
            lostPaneProcessIDs: [lostName: 100],
            lockProcessIDsBySessionID: ["a117957d-44d3-4375-b552-4373d8e5e74a": 103, "elsewhere": 900],
            tree: tree
        )

        #expect(matches == [lostName: "a117957d-44d3-4375-b552-4373d8e5e74a"])
    }

    @Test func ambiguousOrUnrelatedLocksNameNothing() {
        let tree = ProcessTree(parentProcessIDs: [100: 50, 101: 100, 102: 100, 200: 50])

        #expect(
            LostKiroCLIs.sessionIDs(
                lostPaneProcessIDs: [lostName: 100],
                lockProcessIDsBySessionID: ["one": 101, "two": 102], tree: tree
            ).isEmpty)
        #expect(
            LostKiroCLIs.sessionIDs(
                lostPaneProcessIDs: [lostName: 100],
                lockProcessIDsBySessionID: ["one": 200], tree: tree
            ).isEmpty)
        #expect(
            LostKiroCLIs.sessionIDs(
                lostPaneProcessIDs: [lostName: 100],
                lockProcessIDsBySessionID: ["one": 101],
                tree: ProcessTree(parentProcessIDs: [101: 101])
            ).isEmpty)
    }
}
