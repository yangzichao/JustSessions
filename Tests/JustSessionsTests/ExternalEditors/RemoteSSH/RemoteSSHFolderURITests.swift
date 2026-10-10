import Testing
@testable import JustSessions

struct RemoteSSHFolderURITests {
    @Test func keepsALowercaseHostAliasAsItIs() {
        #expect(RemoteSSHFolderURI.string(destination: "justsessions-test", path: "/home/ubuntu/app")
            == "vscode-remote://ssh-remote+justsessions-test/home/ubuntu/app")
    }

    /// Hex of `{"hostName":"devbox.local","user":"me"}`, as the Remote - SSH extension writes it.
    @Test func encodesAUserAsHexJSON() {
        #expect(RemoteSSHFolderURI.string(destination: "me@devbox.local", path: "/srv/app")
            == "vscode-remote://ssh-remote+"
            + "7b22686f73744e616d65223a22646576626f782e6c6f63616c222c2275736572223a226d65227d/srv/app")
    }

    /// Hex of `{"hostName":"DevBox"}`: VS Code lowercases a plain authority, which would lose the capitals.
    @Test func encodesCapitalLettersAsHexJSON() {
        #expect(RemoteSSHFolderURI.string(destination: "DevBox", path: "/srv/app")
            == "vscode-remote://ssh-remote+7b22686f73744e616d65223a22446576426f78227d/srv/app")
    }

    @Test func percentEncodesThePath() {
        #expect(RemoteSSHFolderURI.string(destination: "devbox", path: "/home/me/my project#2?draft")
            == "vscode-remote://ssh-remote+devbox/home/me/my%20project%232%3Fdraft")
    }

    @Test func makesARelativePathAbsolute() {
        #expect(RemoteSSHFolderURI.string(destination: "devbox", path: "srv/app")
            == "vscode-remote://ssh-remote+devbox/srv/app")
    }
}
