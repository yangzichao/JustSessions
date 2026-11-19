import Foundation

enum TabHoverCardTarget: Hashable, Sendable {
    case tab(UUID)
    case group(String)
}
