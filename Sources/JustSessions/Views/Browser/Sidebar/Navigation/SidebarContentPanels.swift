import SwiftUI

/// Keep both native scroll views mounted so switching lists retains their offsets and view state.
struct SidebarContentPanels<Projects: View, OpenTabs: View>: View {
    let selection: SidebarContentMode
    @ViewBuilder let projects: () -> Projects
    @ViewBuilder let openTabs: () -> OpenTabs

    var body: some View {
        ZStack(alignment: .topLeading) {
            projects()
                .opacity(selection == .projects ? 1 : 0)
                .allowsHitTesting(selection == .projects)
                .disabled(selection != .projects)
                .accessibilityHidden(selection != .projects)
            openTabs()
                .opacity(selection == .openTabs ? 1 : 0)
                .allowsHitTesting(selection == .openTabs)
                .disabled(selection != .openTabs)
                .accessibilityHidden(selection != .openTabs)
        }
    }
}
