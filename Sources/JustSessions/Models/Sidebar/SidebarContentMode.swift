import Foundation

/// Each window remembers which list is visible; switching never changes the selected terminal.
enum SidebarContentMode: String, CaseIterable {
    case projects
    case openTabs
}
