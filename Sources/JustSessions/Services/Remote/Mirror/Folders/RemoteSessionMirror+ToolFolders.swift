import Foundation

extension RemoteSessionMirror {
    func lookUpToolFolders(host: String, connectionSharingOptions: [String] = []) throws -> RemoteToolFolders {
        try Task.checkCancellation()
        let folders = try toolFoldersLookup(host, connectionSharingOptions)
        try Task.checkCancellation()
        let file = toolFoldersFile(host: host)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(folders).write(to: file, options: .atomic)
        return folders
    }

    func savedToolFolders(host: String) -> RemoteToolFolders {
        guard let data = try? Data(contentsOf: toolFoldersFile(host: host)),
            let folders = try? JSONDecoder().decode(RemoteToolFolders.self, from: data)
        else { return .standard }
        return folders
    }

    private func toolFoldersFile(host: String) -> URL {
        cacheRoot.appendingPathComponent(Self.directoryName(forHost: host)).appendingPathComponent("tool-folders.json")
    }
}
