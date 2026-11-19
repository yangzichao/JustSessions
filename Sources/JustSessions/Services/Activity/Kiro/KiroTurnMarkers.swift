import Foundation

/// The turns Kiro CLI has under way, as it marks them itself. While a turn runs, Kiro's TUI keeps
/// `<data folder>/kiro-cli/run/turn-markers/<pid>-<turn start in ms>.json`, and takes it away when the turn ends,
/// also within a second of Ctrl-C or Esc cancelling it, which no `Stop` hook reports. It does so under both its V2 and
/// V3 engines. The data folder is `~/Library/Application Support` on macOS and `${XDG_DATA_HOME:-~/.local/share}` on
/// Linux. The pid is the TUI's, below the `kiro-cli` and `kiro-cli-chat chat` processes a tab starts, so a tab's CLI
/// is matched by its process tree, as Claude Code's wrapper scripts are.
///
/// The folder is undocumented: Kiro CLI 2.31.1 keeps it, and 2.16.2 doesn't. A Kiro too old to keep one tells
/// nothing, rather than seeming idle. Kiro marks nothing while it asks for permission, so that reads as working.
struct KiroTurnMarkers: Sendable {
    static let workingName = "working"
    static let idleName = "idle"

    let directory: URL

    init(directory: URL = Self.thisMacDirectory) {
        self.directory = directory
    }

    static var thisMacDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kiro-cli/run/turn-markers", isDirectory: true)
    }

    func processIDsWithATurn() -> Set<Int32>? {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return nil }
        return Set(names.compactMap(Self.processID(inMarkerName:)))
    }

    static func processID(inMarkerName name: String) -> Int32? {
        guard name.hasSuffix(".json"), let dash = name.firstIndex(of: "-") else { return nil }
        return Int32(name[..<dash])
    }

    static func activity(processIDsWithATurn: Set<Int32>, cliProcessIDs: [Int32]) -> CLIActivity {
        cliProcessIDs.contains(where: processIDsWithATurn.contains) ? .working : .idle
    }

    static func activity(named name: String) -> CLIActivity? {
        switch name {
        case workingName: .working
        case idleName: .idle
        default: nil
        }
    }
}
