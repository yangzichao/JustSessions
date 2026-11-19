import Foundation

enum SessionDeletionRequest {
    case conversation(Conversation)
    case conversations([Conversation])
    case project(String)
    case projectRemoval(String)
    case selectedProjectsRemoval(Set<String>)
}
