import Foundation

struct GitHubUpdateConfiguration: Sendable {
    static let repositoryURL = "https://github.com/yangzichao/claudex-macos.git"

    let sourceDirectory: URL
    let bundledRevision: String

    static func current() throws -> GitHubUpdateConfiguration {
        guard let sourcePath = Bundle.main.object(forInfoDictionaryKey: "ClaudexSourceDirectory") as? String,
              let bundledRevision = Bundle.main.object(forInfoDictionaryKey: "ClaudexSourceRevision") as? String else {
            throw AppUpdateError("This app has no source checkout information. Rebuild it with Scripts/build-app.sh.")
        }
        return GitHubUpdateConfiguration(
            sourceDirectory: URL(fileURLWithPath: sourcePath).standardizedFileURL,
            bundledRevision: bundledRevision
        )
    }
}

struct GitHubUpdateCheck: Sendable {
    let latestRevision: String
    let bundledRevision: String

    var isUpdateAvailable: Bool { latestRevision != bundledRevision }
}

struct AppUpdateError: LocalizedError, Sendable {
    let message: String

    init(_ message: String) { self.message = message }

    var errorDescription: String? { message }
}

enum GitHubUpdateChecker {
    static func check(_ configuration: GitHubUpdateConfiguration) throws -> GitHubUpdateCheck {
        let sourceDirectory = configuration.sourceDirectory
        guard FileManager.default.fileExists(atPath: sourceDirectory.appendingPathComponent(".git").path) else {
            throw AppUpdateError("The source checkout is missing at \(sourceDirectory.path).")
        }

        let branch = try git(["branch", "--show-current"], in: sourceDirectory)
        guard branch == "main" else {
            throw AppUpdateError("Switch the source checkout to its main branch before updating.")
        }
        guard try git(["status", "--porcelain"], in: sourceDirectory).isEmpty else {
            throw AppUpdateError("The source checkout has uncommitted changes. Commit or stash them before updating.")
        }

        let remoteOutput = try git(["ls-remote", GitHubUpdateConfiguration.repositoryURL, "refs/heads/main"], in: sourceDirectory)
        guard let latestRevision = remoteOutput.split(separator: "\t").first.map(String.init),
              latestRevision.count == 40,
              latestRevision.allSatisfy(\.isHexDigit) else {
            throw AppUpdateError("GitHub did not return a valid main branch revision.")
        }
        return GitHubUpdateCheck(
            latestRevision: latestRevision,
            bundledRevision: configuration.bundledRevision
        )
    }

    private static func git(_ arguments: [String], in directory: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        do {
            try process.run()
        } catch {
            throw AppUpdateError("Could not run Git: \(error.localizedDescription)")
        }
        let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppUpdateError(output.isEmpty ? "Git exited with status \(process.terminationStatus)." : output)
        }
        return output
    }
}
