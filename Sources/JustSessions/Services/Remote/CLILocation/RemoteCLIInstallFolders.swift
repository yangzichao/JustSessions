import Foundation

/// The folders an SSH host is searched in for a CLI its login shell doesn't find: where the CLIs' installers and
/// package managers put them, the same folders this Mac looks in; see `CLISearchDirectories`. A login shell that
/// skips the startup file adding one to PATH, as `$SHELL -lc` skips `.bashrc`, still finds the CLI this way.
enum RemoteCLIInstallFolders {
    static let hostHome = "$HOME"

    /// An `sh` script that prints `<executable name> <path>` for each executable it finds in the folders, in their
    /// order, then in each nvm version's `bin`; `preferredPath(among:)` picks one. It has no single quote or
    /// backslash, so quoting it again for a fish login shell keeps it as it is.
    static func searchScript(executableNames: [String]) -> String {
        let folders =
            CLISearchDirectories.wellKnownDirectories(homeDirectory: hostHome).map { "\"\($0)\"" }
            + ["\"\(CLISearchDirectories.nvmVersionsDirectory(homeDirectory: hostHome))\"/*/bin"]
        return "for name in \(executableNames.joined(separator: " ")); do"
            + " for folder in \(folders.joined(separator: " ")); do"
            + " [ -x \"$folder/$name\" ] && [ ! -d \"$folder/$name\" ] && echo \"$name $folder/$name\";"
            + " done; done; true"
    }

    static func preferredPath(among paths: [String]) -> String? {
        if let path = paths.first(where: { nodeVersion(of: $0) == nil }) { return path }
        return paths.max { first, second in
            CLISearchDirectories.isNewerNodeVersion(nodeVersion(of: second) ?? "", than: nodeVersion(of: first) ?? "")
        }
    }

    private static func nodeVersion(of path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)
        guard components.count >= 6,
            Array(components.suffix(6).prefix(3)) == [".nvm", "versions", "node"]
        else { return nil }
        return components[components.count - 3]
    }
}
