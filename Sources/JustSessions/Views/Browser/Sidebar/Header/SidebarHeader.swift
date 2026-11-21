import SwiftUI

struct SidebarHeader: View {
    let store: ConversationStore
    @Binding var searchText: String
    var searchScope: Binding<SidebarSearchScope>?
    var contentMode: SidebarContentMode = .projects
    let onNewSession: () -> Void

    @State private var isSearchOpen = false

    private var isSearchShown: Bool {
        isSearchOpen || !searchText.isEmpty
    }

    private var isSearchScopePickerShown: Bool {
        isSearchShown && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if isSearchShown {
                    SidebarSearchField(
                        text: $searchText,
                        placeholder: searchLabel,
                        accessibilityLabel: searchFieldAccessibilityLabel,
                        onClose: closeSearch
                    )
                    .onboardingTourStop(searchTourStop)
                } else {
                    markAndActions
                }
            }
            .frame(height: InterfaceScale.points(46))
            if let searchScope, isSearchScopePickerShown {
                SidebarSearchScopePicker(selection: searchScope)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private var searchFieldAccessibilityLabel: LocalizedStringKey {
        switch (contentMode, searchScope?.wrappedValue) {
        case (.openTabs, _): "Search open tabs by title, project, or host"
        case (.projects, .namesOnly): "Search projects by name or path and sessions by title or ID"
        case (.projects, _): "Search projects by name or path and sessions by title, ID, or message text"
        }
    }

    private var markAndActions: some View {
        HStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    appMark
                    Text("JustSessions")
                        .font(ThemeFont.heading)
                        .lineLimit(1)
                }
                appMark
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                searchButton
                SidebarNotificationBellButton(store: store)
                SidebarNewSessionButton(action: onNewSession)
                    .onboardingTourStop(.newSession)
            }
            .layoutPriority(1)
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
    }

    private var appMark: some View {
        JustSessionsMark()
            .frame(width: InterfaceScale.points(21), height: InterfaceScale.points(18))
    }

    private var searchButton: some View {
        Button {
            isSearchOpen = true
        } label: {
            Image(systemName: "magnifyingglass")
                .frame(width: InterfaceScale.points(24), height: InterfaceScale.points(24))
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle())
        .help(searchLabel)
        .accessibilityLabel(searchLabel)
        .onboardingTourStop(searchTourStop)
    }

    private var searchTourStop: OnboardingTourStop? {
        contentMode == .projects ? .searchSessions : nil
    }

    private var searchLabel: LocalizedStringKey {
        switch (contentMode, searchScope?.wrappedValue) {
        case (.openTabs, _): "Search open tabs"
        case (.projects, .namesOnly): "Search project and session names"
        case (.projects, _): "Search projects and sessions"
        }
    }

    private func closeSearch() {
        searchText = ""
        isSearchOpen = false
    }
}
