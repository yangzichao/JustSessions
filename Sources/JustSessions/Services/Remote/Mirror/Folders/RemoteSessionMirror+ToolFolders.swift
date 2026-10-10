import Foundation

extension RemoteSessionMirror {
    /// Finds where the host keeps each tool's files, and keeps the answer beside the host's copy, so deleting one of
    /// its sessions later reaches the folder the session was copied from.
    func lookUpToolFolders(host: String) throws -> RemoteToolFolders {
        let folders = try toolFoldersLookup(host)
        let file = toolFoldersFile(host: host)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(folders).write(to: file, options: .atomic)
        return folders
    }

    /// The folders of the host's last copy, or the standard ones before its first.
    func savedToolFolders(host: String) -> RemoteToolFolders {
        guard let data = try? Data(contentsOf: toolFoldersFile(host: host)),
              let folders = try? JSONDecoder().decode(RemoteToolFolders.self, from: data) else { return .standard }
        return folders
    }

    private func toolFoldersFile(host: String) -> URL {
        cacheRoot.appendingPathComponent(Self.directoryName(forHost: host)).appendingPathComponent("tool-folders.json")
    }
}
