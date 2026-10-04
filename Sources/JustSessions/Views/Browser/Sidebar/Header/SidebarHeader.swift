import SwiftUI

/// One short line for the app mark and name, then search and new session as icons, so the session list gets
/// the height. Search opens into a field across the whole line, and goes back to its icon when closed, or once it is
/// empty and loses focus.
struct SidebarHeader: View {
    @Binding var searchText: String
    var contentMode: SidebarContentMode = .projects
    let onNewSession: () -> Void

    @State private var isSearchOpen = false

    /// A search with text stays open, so the list is never narrowed by a field out of sight.
    private var isSearchShown: Bool {
        isSearchOpen || !searchText.isEmpty
    }

    var body: some View {
        Group {
            if isSearchShown {
                SidebarSearchField(
                    text: $searchText,
                    placeholder: searchLabel,
                    accessibilityLabel: contentMode == .projects
                        ? "Search projects by name or path and sessions by title or ID"
                        : "Search open tabs by title, project, or host",
                    onClose: closeSearch
                )
            } else {
                markAndActions
            }
        }
        .frame(height: 46)
    }

    private var markAndActions: some View {
        HStack(spacing: 8) {
            JustSessionsMark()
                .frame(width: 21, height: 18)
            Text("JustSessions")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                searchButton
                SidebarNewSessionButton(action: onNewSession)
            }
            .layoutPriority(1)
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
    }

    private var searchButton: some View {
        Button { isSearchOpen = true } label: {
            Image(systemName: "magnifyingglass")
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle())
        .help(searchLabel)
        .accessibilityLabel(searchLabel)
    }

    private var searchLabel: LocalizedStringKey {
        contentMode == .projects ? "Search projects and sessions" : "Search open tabs"
    }

    private func closeSearch() {
        searchText = ""
        isSearchOpen = false
    }
}
