import Foundation

/// What a delete action asked to remove, kept while the confirmation dialog is open.
enum SessionDeletionRequest {
    case conversation(Conversation)
    case conversations([Conversation])
    /// Every deletable session in the project with this `projectDirectoryKey`.
    case project(String)
    /// Every deletable session in the project with this `projectDirectoryKey`, then the project leaves the sidebar.
    case projectRemoval(String)
    /// Every deletable session in the projects selected in the sidebar, by `projectDirectoryKey`, then the projects
    /// leave the sidebar.
    case selectedProjectsRemoval(Set<String>)
}
