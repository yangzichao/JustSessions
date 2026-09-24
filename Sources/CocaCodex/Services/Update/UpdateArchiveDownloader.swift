import CryptoKit
import Foundation

struct DownloadedUpdateArchive: Sendable {
    let directory: URL
    let archive: URL
}

enum UpdateArchiveDownloader {
    static func download(_ update: GitHubUpdateCheck) async throws -> DownloadedUpdateArchive {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("coca-codex-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        do {
            var request = URLRequest(url: update.archiveURL, cachePolicy: .reloadIgnoringLocalCacheData)
            request.setValue("coca-codex", forHTTPHeaderField: "User-Agent")
            let (temporaryArchive, response) = try await URLSession.shared.download(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw AppUpdateError("Could not download the app archive from GitHub.")
            }
            let archive = directory.appendingPathComponent("coca-codex.zip")
            try FileManager.default.moveItem(at: temporaryArchive, to: archive)
            guard try sha256(of: archive) == update.archiveSHA256 else {
                throw AppUpdateError("The downloaded app archive failed its SHA-256 check.")
            }
            return DownloadedUpdateArchive(directory: directory, archive: archive)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
