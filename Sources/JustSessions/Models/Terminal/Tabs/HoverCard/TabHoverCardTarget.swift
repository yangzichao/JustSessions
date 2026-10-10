import Foundation

/// What a hover card in the tab bar is about: one tab, or a tab group by its label.
enum TabHoverCardTarget: Hashable, Sendable {
    case tab(UUID)
    /// A group, named by its project key.
    case group(String)
}
