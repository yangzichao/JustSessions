import Foundation

enum ThisMacFolderResolver {
    static func resolvedPath(of typedFolder: String, creatingMissingFolder: Bool = false) throws -> String {
        let path = absolutePath(of: typedFolder)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { throw ThisMacFolderResolutionError.notAFolder(folder: typedFolder) }
            return path
        }
        guard creatingMissingFolder else { throw ThisMacFolderResolutionError.missingFolder(folder: typedFolder) }
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch {
            throw ThisMacFolderResolutionError.couldNotCreateFolder(folder: typedFolder)
        }
        return path
    }

    static func absolutePath(of typedFolder: String) -> String {
        let expandedFolder = (typedFolder as NSString).expandingTildeInPath
        let absoluteFolder = expandedFolder.hasPrefix("/") ? expandedFolder : NSHomeDirectory() + "/" + expandedFolder
        return URL(fileURLWithPath: absoluteFolder).standardizedFileURL.path
    }
}
