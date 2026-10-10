import Testing
@testable import JustSessions

struct SSHProcessEnvironmentTests {
    @Test func theLoginShellsAgentAndPathWin() {
        let environment = SSHProcessEnvironment.merged(
            inherited: [
                "SSH_AUTH_SOCK": "/private/tmp/com.apple.launchd.abc/Listeners",
                "PATH": "/usr/bin:/bin",
                "__CFBundleIdentifier": "dev.zichaoyang.justsessions",
            ],
            loginShell: [
                "SSH_AUTH_SOCK": "/Users/me/.1password/agent.sock",
                "PATH": "/opt/homebrew/bin:/usr/bin:/bin",
                "AWS_PROFILE": "work",
            ]
        )

        #expect(environment == [
            "SSH_AUTH_SOCK": "/Users/me/.1password/agent.sock",
            "PATH": "/opt/homebrew/bin:/usr/bin:/bin",
            "AWS_PROFILE": "work",
            "__CFBundleIdentifier": "dev.zichaoyang.justsessions",
        ])
    }

    @Test func theShellsRecordOfItselfIsLeftOut() {
        let environment = SSHProcessEnvironment.merged(
            inherited: ["PWD": "/"],
            loginShell: ["PWD": "/Users/me", "OLDPWD": "/tmp", "SHLVL": "2", "_": "/usr/bin/env", "LANG": "en_US.UTF-8"]
        )

        #expect(environment == ["PWD": "/", "LANG": "en_US.UTF-8"])
    }

    @Test func anUnreadableShellLeavesTheAppsEnvironment() {
        let inherited = ["SSH_AUTH_SOCK": "/private/tmp/com.apple.launchd.abc/Listeners", "PATH": "/usr/bin:/bin"]

        #expect(SSHProcessEnvironment.merged(inherited: inherited, loginShell: [:]) == inherited)
    }
}
