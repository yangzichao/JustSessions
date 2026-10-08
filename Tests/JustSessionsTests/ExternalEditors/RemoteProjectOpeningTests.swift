import Foundation
import Testing
@testable import JustSessions

struct RemoteProjectOpeningTests {
    private let vscode = RemoteProjectOpening.vscodeRemoteSSH(urlScheme: "vscode")
    private let goLand = RemoteProjectOpening.jetBrainsToolbox(productCode: "GO")

    @Test func vscodeForkLinkNamesAPlainHostAsWritten() {
        let antigravityIDE = RemoteProjectOpening.vscodeRemoteSSH(urlScheme: "antigravity-ide")
        #expect(antigravityIDE.link(host: "jryates@max", path: "/home/jryates/my project")?.absoluteString
            == "antigravity-ide://vscode-remote/ssh-remote+jryates@max/home/jryates/my%20project?windowId=_blank")
        #expect(vscode.link(host: "dev-box_2.lan", path: "/srv/app")?.absoluteString
            == "vscode://vscode-remote/ssh-remote+dev-box_2.lan/srv/app?windowId=_blank")
    }

    @Test func vscodeForkLinkHexEncodesHostsAPlainAuthorityCannotCarry() {
        // {"hostName":"Max","user":"jryates"}, which Antigravity IDE's SSH extension resolved to jryates@Max.
        #expect(authority(of: vscode.link(host: "jryates@Max", path: "/srv"))
            == "7b22686f73744e616d65223a224d6178222c2275736572223a226a727961746573227d")
        #expect(decodedHexJSON(authority(of: vscode.link(host: "fe80::1", path: "/srv"))) == #"{"hostName":"fe80::1"}"#)
        #expect(decodedHexJSON(authority(of: vscode.link(host: "a@b@Host", path: "/srv")))
            == #"{"hostName":"Host","user":"a@b"}"#)
    }

    @Test func vscodeForkLinkKeepsReservedCharactersInThePath() throws {
        let link = try #require(vscode.link(host: "max", path: "/srv/a?b#c+d"))
        #expect(link.absoluteString == "vscode://vscode-remote/ssh-remote+max/srv/a%3Fb%23c+d?windowId=_blank")
        #expect(link.query == "windowId=_blank")
    }

    @Test func zedLinkNamesTheHostInItsPath() {
        #expect(RemoteProjectOpening.zed.link(host: "jryates@Max", path: "/home/jryates/my project")?.absoluteString
            == "zed://ssh/jryates@Max/home/jryates/my%20project")
        #expect(RemoteProjectOpening.zed.link(host: "devbox", path: "/srv")?.absoluteString == "zed://ssh/devbox/srv")
        #expect(RemoteProjectOpening.zed.link(host: "fe80::1", path: "/srv")?.absoluteString == "zed://ssh/[fe80::1]/srv")
        #expect(RemoteProjectOpening.zed.link(host: "my,host", path: "/srv") == nil)
        #expect(RemoteProjectOpening.zed.link(host: "@max", path: "/srv") == nil)
    }

    @Test func jetBrainsLinkPassesTheUserOnlyWhenTheHostNamesOne() throws {
        #expect(goLand.link(host: "jryates@max", path: "/home/jryates/my project")?.absoluteString
            == "jetbrains://gateway/ssh/environment?h=max&u=jryates&launchIde=true&ideHint=GO&projectHint=/home/jryates/my%20project")
        // An alias's user and port come from ~/.ssh/config, as Toolbox runs `ssh devbox`.
        #expect(goLand.link(host: "devbox", path: "/srv")?.absoluteString
            == "jetbrains://gateway/ssh/environment?h=devbox&launchIde=true&ideHint=GO&projectHint=/srv")
    }

    @Test func jetBrainsLinkKeepsQuerySeparatorsInThePath() throws {
        let link = try #require(goLand.link(host: "max", path: "/srv/a+b&c=d"))
        #expect(link.query?.hasSuffix("projectHint=/srv/a%2Bb%26c%3Dd") == true)
        let items = try #require(URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "projectHint" }?.value == "/srv/a+b&c=d")
        #expect(items.map(\.name) == ["h", "launchIde", "ideHint", "projectHint"])
    }

    @Test func noLinkForAPathThatIsNotAbsolute() {
        for opening in [vscode, .zed, goLand] {
            #expect(opening.link(host: "max", path: "~/project") == nil)
            #expect(opening.link(host: "max", path: "project") == nil)
        }
    }

    private func authority(of link: URL?) -> String? {
        guard let link, let start = link.absoluteString.range(of: "ssh-remote+") else { return nil }
        return String(link.absoluteString[start.upperBound...].prefix { $0 != "/" })
    }

    private func decodedHexJSON(_ hex: String?) -> String? {
        guard let hex, hex.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return String(bytes: bytes, encoding: .utf8)
    }
}
