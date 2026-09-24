import Foundation
import Testing
@testable import JustSessions

struct AppUpdateTests {
    @Test func acceptsPublishedBuildWithGitHubArchiveAndSHA256() throws {
        let revision = String(repeating: "a", count: 40)
        let digest = String(repeating: "b", count: 64)
        let response = releaseJSON(revision: revision, digest: "sha256:\(digest)", archiveURL: "https://github.com/yangzichao/JustSessions/releases/download/build-\(revision)/JustSessions.zip")

        let update = try GitHubUpdateChecker.parseRelease(response, bundledRevision: String(repeating: "c", count: 40))

        #expect(update.isUpdateAvailable)
        #expect(update.latestRevision == revision)
        #expect(update.archiveSHA256 == digest)
    }

    @Test func rejectsArchiveOutsideGitHub() {
        let revision = String(repeating: "a", count: 40)
        let response = releaseJSON(revision: revision, digest: "sha256:\(String(repeating: "b", count: 64))", archiveURL: "https://example.com/JustSessions.zip")

        #expect(throws: AppUpdateError.self) {
            try GitHubUpdateChecker.parseRelease(response, bundledRevision: revision)
        }
    }

    @Test func rejectsReleaseWithoutNewAppArchive() {
        let revision = String(repeating: "a", count: 40)
        let digest = "sha256:" + String(repeating: "b", count: 64)
        let archiveURL = "https://github.com/yangzichao/JustSessions/releases/download/build-\(revision)/coca-codex.zip"
        let response = releaseJSON(revision: revision, digest: digest, archiveURL: archiveURL, assetName: "coca-codex.zip")

        #expect(throws: AppUpdateError.self) {
            try GitHubUpdateChecker.parseRelease(response, bundledRevision: revision)
        }
    }

    private func releaseJSON(revision: String, digest: String, archiveURL: String, assetName: String = "JustSessions.zip") -> Data {
        Data("""
        {"tag_name":"build-\(revision)","assets":[{"name":"\(assetName)","browser_download_url":"\(archiveURL)","digest":"\(digest)"}]}
        """.utf8)
    }
}
