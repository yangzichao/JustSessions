import Foundation
import Testing

@testable import JustSessions

struct TerminalLinkTargetTests {
    private let projectFolder = "/Users/me/paper"
    private let itemsOnThisMac: [String: TerminalLinkLocalItem.Kind] = [
        "/Users/me/paper/Sources/App/main.swift": .file,
        "/Users/me/paper/Sources": .folder,
        "/Users/me/paper/README.md": .file,
        "/Users/me/notes.md": .file,
        "/Users/me/Shared Notes/plan v2.md": .file,
        "/Users/me": .folder,
    ]

    @Test(arguments: [
        "https://example.com/docs?page=2#intro",
        "http://localhost:3000",
        "HTTPS://EXAMPLE.COM",
        "mailto:someone@example.com",
    ])
    func webPagesAndEmailAddressesAreTakenAsGiven(_ link: String) throws {
        let url = try #require(URL(string: link))
        #expect(target(link, host: .thisMac) == .webAddress(url))
        #expect(target(link, host: .ssh("devbox")) == .webAddress(url))
    }

    @Test(arguments: [
        "ssh://devbox", "vscode://file/Users/me/paper/README.md", "x-apple.systempreferences:com.apple.preference",
        "tel:+15551234567", "magnet:?xt=urn:btih:abc", "javascript:alert(1)",
    ])
    func otherSchemesPointAtNothingOnThisMac(_ link: String) {
        #expect(target(link, host: .thisMac) == nil)
    }

    @Test func aRelativePathIsInTheProjectFolder() {
        #expect(target("Sources/App/main.swift", host: .thisMac) == file("/Users/me/paper/Sources/App/main.swift"))
        #expect(target("./README.md", host: .thisMac) == file("/Users/me/paper/README.md"))
        #expect(target("../notes.md", host: .thisMac) == file("/Users/me/notes.md"))
    }

    @Test func aFolderIsAFolder() {
        #expect(
            target("Sources", host: .thisMac)
                == .localItem(
                    TerminalLinkLocalItem(
                        url: URL(fileURLWithPath: "/Users/me/paper/Sources"), kind: .folder
                    )))
    }

    @Test func theLineAndColumnAfterThePathAreKeptApart() {
        #expect(
            target("Sources/App/main.swift:42", host: .thisMac)
                == file("/Users/me/paper/Sources/App/main.swift", lineNumber: 42))
        #expect(
            target("Sources/App/main.swift:42:7", host: .thisMac)
                == file("/Users/me/paper/Sources/App/main.swift", lineNumber: 42, columnNumber: 7))
        #expect(
            target("/Users/me/paper/Sources/App/main.swift:3", host: .thisMac)
                == file("/Users/me/paper/Sources/App/main.swift", lineNumber: 3))
    }

    /// `README.md:3` reads as a URL whose scheme is `README.md`.
    @Test func aFileNameWithALineNumberIsStillAPath() {
        #expect(target("README.md:3", host: .thisMac) == file("/Users/me/paper/README.md", lineNumber: 3))
        #expect(target("README.md:3", host: .ssh("devbox")) == .remotePath("README.md"))
    }

    @Test func aTildeIsTheHomeFolder() {
        #expect(target("~/notes.md", host: .thisMac) == file("/Users/me/notes.md"))
        #expect(target("~", host: .thisMac) == .localItem(TerminalLinkLocalItem(url: URL(fileURLWithPath: "/Users/me"), kind: .folder)))
    }

    @Test func aFileURLIsItsFile() {
        #expect(target("file:///Users/me/Shared%20Notes/plan%20v2.md", host: .thisMac) == file("/Users/me/Shared Notes/plan v2.md"))
        #expect(target("file://localhost/Users/me/notes.md", host: .thisMac) == file("/Users/me/notes.md"))
    }

    @Test func aPathWithSpacesIsTakenAsPrinted() {
        #expect(target("/Users/me/Shared Notes/plan v2.md", host: .thisMac) == file("/Users/me/Shared Notes/plan v2.md"))
    }

    @Test(arguments: ["Sources/App/missing.swift", "Sources/App/missing.swift:42", "/etc/nothing-here", "  "])
    func aMissingFilePointsAtNothing(_ link: String) {
        #expect(target(link, host: .thisMac) == nil)
    }

    @Test(arguments: [
        ("Sources/App/main.swift", "Sources/App/main.swift"),
        ("Sources/App/main.swift:42:7", "Sources/App/main.swift"),
        ("/srv/app/notes.md", "/srv/app/notes.md"),
        ("~/notes.md", "~/notes.md"),
        ("file:///srv/app/notes.md", "/srv/app/notes.md"),
    ])
    func aPathInATabOnAnSSHHostIsOnTheHost(_ link: String, path: String) {
        #expect(target(link, host: .ssh("devbox")) == .remotePath(path))
    }

    @Test func aURLWithAnotherSchemeInATabOnAnSSHHostIsNoPath() {
        #expect(target("vscode://file/srv/app/notes.md", host: .ssh("devbox")) == nil)
    }

    @Test func surroundingSpacesAreLeftOut() {
        #expect(target("README.md   ", host: .thisMac) == file("/Users/me/paper/README.md"))
    }

    private func target(_ link: String, host: SessionHost) -> TerminalLinkTarget? {
        TerminalLinkTarget(
            link: link,
            host: host,
            workingDirectory: projectFolder,
            homeDirectory: "/Users/me",
            localItemKind: { itemsOnThisMac[$0.path] }
        )
    }

    private func file(_ path: String, lineNumber: Int? = nil, columnNumber: Int? = nil) -> TerminalLinkTarget {
        .localItem(
            TerminalLinkLocalItem(
                url: URL(fileURLWithPath: path), kind: .file, lineNumber: lineNumber, columnNumber: columnNumber
            ))
    }
}
