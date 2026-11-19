import Foundation
import Testing

@testable import JustSessions

/// The sign-ins of a store's own, with each host's command run as a local `sh` script and its check answered by the
/// test, so no test reaches a host.
@MainActor
struct RemoteSignInsTests {
    private final class Fakes: @unchecked Sendable {
        let lock = NSLock()
        var script = "exit 0"
        var checkStatus: Int32? = 0
        var checksRun = 0
        var notifiedHosts: [String] = []
        var isAppActive = true

        func setScript(_ script: String) { lock.withLock { self.script = script } }
        func setCheckStatus(_ status: Int32?) { lock.withLock { checkStatus = status } }
        var checks: Int { lock.withLock { checksRun } }
    }

    private let isolatedUserDefaults: IsolatedUserDefaults
    private let fakes = Fakes()
    private let store: ConversationStore
    private let signIns: RemoteSignIns

    init() throws {
        isolatedUserDefaults = try IsolatedUserDefaults()
        store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults, startsBackgroundPolling: false)
        signIns = Self.signIns(userDefaults: isolatedUserDefaults.userDefaults, fakes: fakes, store: store)
    }

    private static func signIns(userDefaults: UserDefaults, fakes: Fakes, store: ConversationStore) -> RemoteSignIns {
        RemoteSignIns(
            userDefaults: userDefaults,
            runCheck: { _, _ in
                fakes.lock.withLock {
                    fakes.checksRun += 1
                    return fakes.checkStatus
                }
            },
            makeSession: { host, command in
                let script = fakes.lock.withLock { fakes.script }
                return RemoteSignInSession(
                    host: host,
                    command: command,
                    launcher: RemoteSignInSession.Launcher { _, _ in
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/bin/sh")
                        process.arguments = ["-c", script]
                        return process
                    },
                    timing: RemoteSignInSession.Timing(
                        promptPause: .milliseconds(50),
                        linePause: .milliseconds(200),
                        pollInterval: .milliseconds(20),
                        timeLimit: .seconds(120)
                    )
                )
            },
            notify: { fakes.notifiedHosts.append($0) },
            isAppActive: { fakes.isAppActive },
            frontStore: { store }
        )
    }

    private func command(check: String? = nil, hours: Int = 10) -> RemoteSignInCommand {
        RemoteSignInCommand(command: "sign-in", checkCommand: check, intervalHours: hours)!
    }

    @Test func aNewCommandSignsInAtOnceAndAgainOnceItsIntervalHasPassed() async throws {
        defer { isolatedUserDefaults.removeSuite() }
        let start = Date.now

        signIns.setCommand(command(hours: 10), on: "devbox", now: start)
        #expect(signIns.state(on: "devbox") == .signingIn)
        #expect(signIns.presentingStoreID == ObjectIdentifier(store))
        try await expectEventually { signIns.state(on: "devbox") == .signedIn }

        let signedInAt = try #require(signIns.settings.signedInAt(on: "devbox"))
        signIns.lookAtHosts(["devbox"], needingLogIn: [], now: signedInAt.addingTimeInterval(9 * 3600))
        #expect(signIns.state(on: "devbox") == .signedIn)
        signIns.lookAtHosts(["devbox"], needingLogIn: [], now: signedInAt.addingTimeInterval(11 * 3600))
        signIns.lookAtHosts(["devbox"], needingLogIn: [], now: signedInAt.addingTimeInterval(12 * 3600))

        // Come due while you use the app: a notification, once, and no dialog.
        #expect(signIns.state(on: "devbox") == .due)
        #expect(fakes.notifiedHosts == ["devbox"])
        #expect(signIns.presentingStoreID == nil)
    }

    @Test func dueWhileTheAppIsAwayNotifiesThenOpensWhenTheAppComesForward() async throws {
        defer { isolatedUserDefaults.removeSuite() }
        fakes.isAppActive = false

        signIns.setCommand(command(), on: "devbox")
        #expect(signIns.state(on: "devbox") == .due)
        #expect(fakes.notifiedHosts == ["devbox"])

        fakes.isAppActive = true
        signIns.appCameForward()

        #expect(signIns.state(on: "devbox") == .signingIn)
        try await expectEventually { signIns.state(on: "devbox") == .signedIn }
    }

    @Test func theCheckCommandSaysWhenASignInIsDue() async throws {
        defer { isolatedUserDefaults.removeSuite() }
        fakes.isAppActive = false
        let start = Date.now
        fakes.setCheckStatus(0)

        signIns.setCommand(command(check: "check"), on: "devbox", now: start)
        try await expectEventually { signIns.state(on: "devbox") == .signedIn }

        // Not asked again within 5 minutes, nor while the host needs Connect….
        fakes.setCheckStatus(1)
        signIns.lookAtHosts(["devbox"], needingLogIn: [], now: start.addingTimeInterval(60))
        signIns.lookAtHosts(["devbox"], needingLogIn: ["devbox"], now: start.addingTimeInterval(400))
        #expect(fakes.checks == 1)

        signIns.lookAtHosts(["devbox"], needingLogIn: [], now: start.addingTimeInterval(400))
        try await expectEventually { signIns.state(on: "devbox") == .due }
        #expect(fakes.notifiedHosts == ["devbox"])

        // A host that can't be reached tells nothing.
        fakes.setCheckStatus(RemoteHostCommandRunner.connectionFailureExitStatus)
        signIns.lookAtHosts(["devbox"], needingLogIn: [], now: start.addingTimeInterval(800))
        try await expectEventually { fakes.checks == 3 }
        try await Task.sleep(for: .milliseconds(100))
        #expect(signIns.state(on: "devbox") == .due)
    }

    @Test func aCancelledSignInStaysDueAndDoesntOpenAgainByItself() async throws {
        defer { isolatedUserDefaults.removeSuite() }
        fakes.setScript("printf 'PIN: '; read pin; sleep 600")

        signIns.setCommand(command(), on: "devbox")
        try await expectEventually { signIns.prompter.question?.prompt == "PIN:" }
        signIns.prompter.answer(nil)
        try await expectEventually { signIns.state(on: "devbox") == .due }

        signIns.appCameForward()
        #expect(signIns.state(on: "devbox") == .due)
        #expect(signIns.presentingStoreID == nil)
    }

    @Test func aFailedSignInSaysWhyInItsWindow() async throws {
        defer { isolatedUserDefaults.removeSuite() }
        fakes.setScript("echo 'Your account is locked'; exit 2")

        signIns.setCommand(command(), on: "devbox")
        try await expectEventually { store.alert != nil }

        #expect(store.alert?.title == "Couldn't sign in on devbox")
        #expect(store.alert?.message.contains("Your account is locked") == true)
        #expect(signIns.state(on: "devbox") == .due)
    }

    @Test func theCommandAndTheLastSignInOutliveARelaunchAndARemovedHostForgetsThem() async throws {
        defer { isolatedUserDefaults.removeSuite() }
        signIns.setCommand(command(check: "check", hours: 8), on: "devbox")
        try await expectEventually { signIns.state(on: "devbox") == .signedIn }
        signIns.setCommand(command(hours: 8), on: "build")
        try await expectEventually { signIns.state(on: "build") == .signedIn }

        let relaunched = Self.signIns(userDefaults: isolatedUserDefaults.userDefaults, fakes: fakes, store: store)
        #expect(relaunched.command(on: "devbox") == command(check: "check", hours: 8))
        #expect(relaunched.settings.signedInAt(on: "build") != nil)

        relaunched.forget("build")
        let afterRemoval = Self.signIns(userDefaults: isolatedUserDefaults.userDefaults, fakes: fakes, store: store)
        #expect(afterRemoval.command(on: "build") == nil)
        #expect(afterRemoval.settings.signedInAt(on: "build") == nil)
        #expect(afterRemoval.command(on: "devbox") != nil)
    }

    @Test func aCommandIsTrimmedAndAnEmptyCheckCommandIsNone() {
        defer { isolatedUserDefaults.removeSuite() }
        #expect(RemoteSignInCommand(command: "  ") == nil)
        let trimmed = RemoteSignInCommand(command: " sign-in --renew \n", checkCommand: "   ", intervalHours: 0)
        #expect(trimmed?.command == "sign-in --renew")
        #expect(trimmed?.checkCommand == nil)
        #expect(trimmed?.intervalHours == 1)
    }
}
