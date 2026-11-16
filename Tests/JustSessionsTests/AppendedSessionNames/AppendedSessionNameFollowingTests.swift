import Foundation
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized, .oneHeldThreadAtATime)
struct AppendedSessionNameFollowingTests {
    @Test func aBusyFilesReadLeavesTheMainActorFreeAndAppliesItsName() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let gate = NameReadGate()
        let readers = AppendedSessionNameReaders(readLines: { gate.read(&$0) })
        await fixture.store.followAppendedSessionNames(readers: readers, codexDirectory: fixture.folder)
        try fixture.appendName()
        gate.arm()
        let following = Task { await fixture.store.followAppendedSessionNames(readers: readers, codexDirectory: fixture.folder) }
        do {
            // This runs on the main actor while the file reader is still blocked.
            try await expectEventually { gate.hasStarted }
            let readOnMainThread = gate.readOnMainThread
            #expect(!readOnMainThread)
        } catch {
            gate.release()
            await following.value
            throw error
        }
        gate.release()
        await following.value
        #expect(fixture.tab.displayTitle == "background-name")
        let current = try #require(fixture.store.conversation(withID: fixture.conversation.id))
        #expect(fixture.store.title(for: current) == "background-name")
    }

    enum Change: CaseIterable, Sendable { case closed, ended, relinked }

    @Test(arguments: Change.allCases)
    func aNameReadBeforeTheTabChangedCannotRenameItsNewSession(_ change: Change) async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let gate = NameReadGate()
        let readers = AppendedSessionNameReaders(readLines: { gate.read(&$0) })
        await fixture.store.followAppendedSessionNames(readers: readers, codexDirectory: fixture.folder)
        try fixture.appendName()
        gate.arm()
        let following = Task { await fixture.store.followAppendedSessionNames(readers: readers, codexDirectory: fixture.folder) }
        do {
            try await expectEventually { gate.hasStarted }
            switch change {
            case .closed: fixture.store.closeTerminal(fixture.tab.id)
            case .ended: fixture.tab.processFinished(exitCode: 0)
            case .relinked:
                let other = Conversation.fixture(provider: .pi, title: "Other", sourceFile: fixture.folder.appendingPathComponent("other.jsonl"))
                fixture.tab.synchronize(conversation: other, displayTitle: "Other")
            }
        } catch {
            gate.release()
            await following.value
            throw error
        }
        gate.release()
        await following.value
        #expect(fixture.tab.displayTitle == (change == .relinked ? "Other" : "Session"))
        #expect(fixture.store.conversation(withID: fixture.conversation.id)?.suggestedTitle == "Session")
    }

    @MainActor
    private struct Fixture {
        let folder: URL
        let settings: IsolatedUserDefaults
        let conversation: Conversation
        let store: ConversationStore
        let tab: TerminalSession

        init() throws {
            folder = try makeTemporaryDirectory()
            settings = try IsolatedUserDefaults()
            let file = folder.appendingPathComponent("session.jsonl")
            try Data("{}\n".utf8).write(to: file)
            conversation = .fixture(provider: .pi, projectPath: folder.path, sourceFile: file)
            store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
            store.replaceConversations(on: .thisMac, with: [conversation])
            tab = TerminalSession(engine: .swiftTerm, conversation: conversation, provider: .pi, projectPath: folder.path,
                                  action: .resume, displayTitle: "Session",
                                  command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [],
                                                            workingDirectory: folder.path, environment: []))
            store.openTerminal(tab)
        }

        func appendName() throws {
            let handle = try FileHandle(forWritingTo: conversation.sourceFile)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("{\"type\":\"session_info\",\"name\":\"background-name\"}\n".utf8))
        }

        func close() {
            store.closeAllTerminals()
            settings.removeSuite()
            try? FileManager.default.removeItem(at: folder)
        }
    }
}

private final class NameReadGate: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var armed = false
    private var started = false
    private var onMainThread = false

    var hasStarted: Bool { lock.withLock { started } }
    var readOnMainThread: Bool { lock.withLock { onMainThread } }
    func arm() { lock.withLock { armed = true } }
    func release() { semaphore.signal() }

    func read(_ reader: inout AppendedJSONLinesReader) -> [Data] {
        let shouldWait = lock.withLock {
            guard armed else { return false }
            armed = false
            started = true
            onMainThread = Thread.isMainThread
            return true
        }
        // Only the test releases this read; a busy main actor can take longer than a wall-clock timeout.
        if shouldWait { semaphore.wait() }
        return reader.newLines()
    }
}
