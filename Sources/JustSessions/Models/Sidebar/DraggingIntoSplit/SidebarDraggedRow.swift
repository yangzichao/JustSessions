import Foundation

enum SidebarDraggedRow: Equatable {
    case session(Conversation)
    case openTab(UUID)
}
