import Foundation

/// What a delete action asked to remove, kept while the confirmation dialog is open.
enum SessionDeletionRequest {
    case conversation(Conversation)
    case conversations([Conversation])
    /// Every deletable session in the project with this `projectDirectoryKey`.
    case project(String)
}
