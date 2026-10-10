import Testing
@testable import JustSessions

struct RemoteHostInputTests {
    @Test(arguments: [
        ("devbox", "devbox"),
        ("  me@devbox \n", "me@devbox"),
        ("ssh devbox", "devbox"),
        ("ssh   me@devbox", "me@devbox"),
        ("ssh -p 22 devbox", "devbox"),
        ("me@devbox:22", "me@devbox"),
        ("ssh://me@devbox", "me@devbox"),
        ("ssh://devbox/", "devbox"),
        ("SSH://me@devbox:22", "me@devbox"),
        ("fe80::1", "fe80::1"),
    ])
    func readsTheDestination(typed: String, destination: String) {
        #expect(RemoteHostInput(typed) == .destination(destination))
    }

    @Test(arguments: [
        ("devbox:2222", nil, "devbox", 2222),
        ("me@10.0.0.5:2200", "me", "10.0.0.5", 2200),
        ("ssh -p 2222 me@10.0.0.5", "me", "10.0.0.5", 2222),
        ("ssh -p2222 devbox", nil, "devbox", 2222),
        ("ssh devbox -p 2222", nil, "devbox", 2222),
        ("ssh://me@devbox:2222", "me", "devbox", 2222),
    ] as [(String, String?, String, Int)])
    func aPortIsShownHowToPutInTheConfig(typed: String, user: String?, hostName: String, port: Int) {
        #expect(RemoteHostInput(typed) == .needsPortInConfig(user: user, hostName: hostName, port: port))
    }

    @Test(arguments: [
        "ssh -i ~/.ssh/key devbox",
        "ssh -J bastion devbox",
        "ssh devbox uptime",
        "ssh",
        "ssh -p devbox",
        "devbox:path",
        "devbox:99999",
        "devbox:",
        "dev box",
        "-oProxyCommand=touch",
        "devbox/home",
        "ssh://devbox/home/me",
        "ssh://me:secret@devbox",
        "..",
    ])
    func anythingElseIsNoDestination(typed: String) {
        #expect(RemoteHostInput(typed) == .notADestination)
    }

    @Test func nothingTypedIsNoProblem() {
        #expect(RemoteHostInput("") == .empty)
        #expect(RemoteHostInput("  \n") == .empty)
    }

    @Test func theConfigLinesGiveTheHostItsPortAndUser() {
        #expect(RemoteHostInput.configLines(user: "me", hostName: "10.0.0.5", port: 2222) == """
            Host 10.0.0.5
              Port 2222
              User me
            """)
        #expect(RemoteHostInput.configLines(user: nil, hostName: "devbox", port: 2222) == "Host devbox\n  Port 2222")
    }
}
