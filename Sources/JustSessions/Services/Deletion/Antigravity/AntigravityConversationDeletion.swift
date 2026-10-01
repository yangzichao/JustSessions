import Foundation

struct AntigravityConversationDeletion {
    let configurationDirectory: URL
    let moveToTrash: (URL) throws -> URL
    let isInUse: ([URL]) throws -> Bool

    init(configurationDirectory: URL, moveToTrash: ((URL) throws -> URL)? = nil, isInUse: (([URL]) throws -> Bool)? = nil) {
        self.configurationDirectory = configurationDirectory
        self.moveToTrash = moveToTrash ?? { file in
            var destination: NSURL?
            try FileManager.default.trashItem(at: file, resultingItemURL: &destination)
            guard let destination else { throw AntigravityDatabaseError.unreadable }
            return destination as URL
        }
        self.isInUse = isInUse ?? Self.filesAreInUse
    }

    func delete(_ conversation: Conversation) throws {
        guard conversation.host == .thisMac else { throw ConversationDeletionError.invalidSource }
        let files = try AntigravityDeletionFiles.validated(for: conversation, configurationDirectory: configurationDirectory)
        guard try !isInUse(files) else { throw AntigravityConversationDeletionError.sessionInUse }
        var movedFiles: [(original: URL, trashed: URL)] = []
        do {
            try AntigravityDeletionIndex.removingEntry(sessionID: conversation.sessionID, configurationDirectory: configurationDirectory) {
                for file in files { movedFiles.append((file, try moveToTrash(file))) }
            }
        } catch {
            var restored = true
            for file in movedFiles.reversed() {
                do { try FileManager.default.moveItem(at: file.trashed, to: file.original) }
                catch { restored = false }
            }
            guard restored else { throw AntigravityConversationDeletionError.couldNotRestoreFiles }
            throw error
        }
    }

    static func filesAreInUse(_ files: [URL]) throws -> Bool {
        guard let result = BoundedProcessRunner.result(
            ofExecutable: "/usr/sbin/lsof", arguments: ["-nP", "-t", "--"] + files.map(\.path),
            includesStandardError: true, timeout: 5
        ) else { throw AntigravityConversationDeletionError.couldNotCheckProcesses }
        if result.exitStatus == 0 { return true }
        guard result.exitStatus == 1, result.output.isEmpty else {
            throw AntigravityConversationDeletionError.couldNotCheckProcesses
        }
        return false
    }
}
