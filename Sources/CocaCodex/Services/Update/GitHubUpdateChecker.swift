import Foundation

struct GitHubUpdateCheck: Sendable {
    let latestRevision: String
    let bundledRevision: String
    let archiveURL: URL
    let archiveSHA256: String

    var isUpdateAvailable: Bool { latestRevision != bundledRevision }
}

struct AppUpdateError: LocalizedError, Sendable {
    let message: String

    init(_ message: String) { self.message = message }

    var errorDescription: String? { message }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name, digest
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case assets
        case tagName = "tag_name"
    }
}

enum GitHubUpdateChecker {
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/yangzichao/coca-codex/releases/latest")!

    static func check(bundledRevision: String) async throws -> GitHubUpdateCheck {
        var request = URLRequest(url: latestReleaseURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("coca-codex", forHTTPHeaderField: "User-Agent")

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw AppUpdateError("GitHub did not return an HTTP response.")
        }
        guard response.statusCode == 200 else {
            throw AppUpdateError(response.statusCode == 404
                ? "No app update has been published on GitHub yet."
                : "GitHub returned HTTP \(response.statusCode).")
        }

        return try parseRelease(responseData, bundledRevision: bundledRevision)
    }

    static func parseRelease(_ responseData: Data, bundledRevision: String) throws -> GitHubUpdateCheck {
        let release = try JSONDecoder().decode(GitHubRelease.self, from: responseData)
        guard release.tagName.hasPrefix("build-") else {
            throw AppUpdateError("The latest GitHub release is not an app update.")
        }
        let latestRevision = String(release.tagName.dropFirst("build-".count))
        guard latestRevision.count == 40, latestRevision.allSatisfy(\.isHexDigit),
              let archive = release.assets.first(where: { $0.name == "coca-codex.zip" }),
              archive.browserDownloadURL.host == "github.com",
              let digest = archive.digest, digest.hasPrefix("sha256:") else {
            throw AppUpdateError("The GitHub app update is incomplete or invalid.")
        }
        let archiveSHA256 = String(digest.dropFirst("sha256:".count))
        guard archiveSHA256.count == 64, archiveSHA256.allSatisfy(\.isHexDigit) else {
            throw AppUpdateError("The GitHub app update has no valid checksum.")
        }
        return GitHubUpdateCheck(
            latestRevision: latestRevision,
            bundledRevision: bundledRevision,
            archiveURL: archive.browserDownloadURL,
            archiveSHA256: archiveSHA256.lowercased()
        )
    }
}
