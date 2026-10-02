import Foundation
@testable import JustSessions

/// A Pi sessions folder in a temporary folder, deleted into a stand-in Trash beside it.
struct PiDeletionSandbox {
    /// What a stand-in Trash throws when told to refuse an item.
    struct MoveRefused: Error, Equatable {}

    let root: URL
    let folder: PiSessionFolderFixture
    let trashDirectory: URL
    let deletion: PiConversationDeletion

    init() throws {
        root = try makeTemporaryDirectory()
        folder = PiSessionFolderFixture(sessionsDirectory: root.appendingPathComponent("sessions"))
        trashDirectory = root.appendingPathComponent("test-trash")
        try FileManager.default.createDirectory(at: folder.sessionsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        deletion = Self.deletion(of: folder.sessionsDirectory, into: trashDirectory) { _ in false }
    }

    /// A deletion into the stand-in Trash that throws `MoveRefused` instead of moving the items `refuses` picks.
    func deletion(refusing refuses: @escaping (URL) -> Bool) -> PiConversationDeletion {
        Self.deletion(of: folder.sessionsDirectory, into: trashDirectory, refusing: refuses)
    }

    private static func deletion(
        of sessionsDirectory: URL,
        into trashDirectory: URL,
        refusing refuses: @escaping (URL) -> Bool
    ) -> PiConversationDeletion {
        PiConversationDeletion(sessionsDirectory: sessionsDirectory) { source in
            if refuses(source) { throw MoveRefused() }
            try FileManager.default.moveItem(at: source, to: trashDirectory.appendingPathComponent(source.lastPathComponent))
        }
    }

    var trashedNames: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: trashDirectory.path)) ?? []).sorted()
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
