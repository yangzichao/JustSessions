import Foundation

extension ConversationProvider {
    var movesSessionsToOtherFolders: Bool { self == .claude }

    /// The arguments, after the resume arguments, that move the session to `folderPath` once its CLI starts. `/cd`
    /// reads the rest of its line as the path, so a path with spaces is passed as it is.
    func moveToFolderArguments(_ folderPath: String) -> [String] {
        initialPromptArguments("/cd \(folderPath)")
    }
}
