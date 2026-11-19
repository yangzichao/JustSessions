import SwiftUI

struct SidebarNotificationBellButton: View {
    let store: ConversationStore
    @Environment(\.locale) private var locale
    @Environment(\.appTheme) private var appTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingList = false

    var body: some View {
        let entries = store.notificationBellEntries
        Button {
            isShowingList.toggle()
        } label: {
            Image(systemName: "bell")
                .frame(width: InterfaceScale.points(24), height: InterfaceScale.points(24))
                .overlay(alignment: .topTrailing) {
                    if !entries.isEmpty {
                        Circle()
                            .fill(ThemePalette.unseenTurn)
                            .frame(width: InterfaceScale.points(6), height: InterfaceScale.points(6))
                            .offset(x: -4, y: 4)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(ThemePlainButtonStyle())
        .help("Waiting for you")
        .accessibilityLabel("Waiting for you")
        .accessibilityValue(Text("\(entries.count) sessions"))
        .popover(isPresented: $isShowingList, arrowEdge: .bottom) {
            NotificationBellList(entries: entries) { entry in
                isShowingList = false
                store.showSession(fromNotificationBell: entry)
            }
            // A native popover can start with its own presentation environment.
            .environment(\.locale, locale)
            .environment(\.appTheme, appTheme)
            .environment(\.colorScheme, colorScheme)
            .onExitCommand { isShowingList = false }
        }
        .onDisappear { isShowingList = false }
    }
}
