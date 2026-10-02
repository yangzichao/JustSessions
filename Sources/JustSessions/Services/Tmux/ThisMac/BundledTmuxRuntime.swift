import Foundation

/// A relocatable, signed runtime shipped inside the app, with its own terminal database.
struct BundledTmuxRuntime: Sendable {
    let directory: URL

    static var appBundleDirectory: URL? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return Bundle.main.resourceURL?.appendingPathComponent("Tmux", isDirectory: true)
    }

    func server(environment: [String: String], fileManager: FileManager) -> ThisMacTmuxServer? {
        let executable = directory.appendingPathComponent("bin/tmux")
        let terminfo = directory.appendingPathComponent("share/terminfo", isDirectory: true)
        guard fileManager.isExecutableFile(atPath: executable.path),
              fileManager.fileExists(atPath: terminfo.path) else { return nil }
        return ThisMacTmuxServer(executablePath: executable.path, environment: environment, terminfoDirectory: terminfo.path)
    }
}
