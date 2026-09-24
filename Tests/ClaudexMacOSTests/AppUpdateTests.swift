import Foundation
import Testing
@testable import ClaudexMacOS

struct AppUpdateTests {
    @Test func acceptsPublishedBuildWithGitHubArchiveAndSHA256() throws {
        let revision = String(repeating: "a", count: 40)
        let digest = String(repeating: "b", count: 64)
        let response = releaseJSON(revision: revision, digest: "sha256:\(digest)", archiveURL: "https://github.com/yangzichao/claudex-macos/releases/download/build-\(revision)/claudex-macos.zip")

        let update = try GitHubUpdateChecker.parseRelease(response, bundledRevision: String(repeating: "c", count: 40))

        #expect(update.isUpdateAvailable)
        #expect(update.latestRevision == revision)
        #expect(update.archiveSHA256 == digest)
    }

    @Test func rejectsArchiveOutsideGitHub() {
        let revision = String(repeating: "a", count: 40)
        let response = releaseJSON(revision: revision, digest: "sha256:\(String(repeating: "b", count: 64))", archiveURL: "https://example.com/claudex-macos.zip")

        #expect(throws: AppUpdateError.self) {
            try GitHubUpdateChecker.parseRelease(response, bundledRevision: revision)
        }
    }

    private func releaseJSON(revision: String, digest: String, archiveURL: String) -> Data {
        Data("""
        {"tag_name":"build-\(revision)","assets":[{"name":"claudex-macos.zip","browser_download_url":"\(archiveURL)","digest":"\(digest)"}]}
        """.utf8)
    }
}
