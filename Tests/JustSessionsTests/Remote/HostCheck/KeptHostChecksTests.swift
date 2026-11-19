import Foundation
import Testing

@testable import JustSessions

struct KeptHostChecksTests {
    @Test func aCheckIsKeptAcrossLaunchesUntilItsHostIsForgotten() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let keptCheck = KeptHostCheck(
            report: HostCheckReport(
                host: "devbox",
                checkedAt: Date(timeIntervalSince1970: 1_000_000),
                thisMacSummary: "JustSessions 1.2.11",
                findings: [HostCheckFinding(id: .tmux, status: .problem, title: "tmux", summary: "Can't reach", hostOutput: "mismatch")],
                endedTabScreen: "[exited]"
            ),
            appVersion: "1.2.11"
        )
        var checks = KeptHostChecks()
        checks.setCheck(keptCheck, for: "devbox")
        checks.save(to: settings.userDefaults)

        #expect(KeptHostChecks.load(from: settings.userDefaults).check(for: "devbox") == keptCheck)

        checks.setCheck(nil, for: "devbox")
        checks.save(to: settings.userDefaults)
        #expect(KeptHostChecks.load(from: settings.userDefaults).check(for: "devbox") == nil)
    }

    @Test func findingIDsAreKeptByTheirNames() throws {
        let ids: [HostCheckFindingID] = [.loginShell, .cli(.antigravity), .otherCLIs]
        let encoded = try JSONEncoder().encode(ids)
        #expect(String(decoding: encoded, as: UTF8.self) == #"["login-shell","cli-agy","cli-others"]"#)
        #expect(try JSONDecoder().decode([HostCheckFindingID].self, from: encoded) == ids)
        #expect(HostCheckFindingID.all.allSatisfy { HostCheckFindingID(rawValue: $0.rawValue) == $0 })
    }
}
