import SwiftUI

/// Whether the bottom of the sidebar shows a random tip each launch. Turning it on shows one right away.
struct HelpRandomTipsToggle: View {
    @ObservedObject var tipsStore: RandomTipsStore = .shared

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Toggle(
                "Show a tip in the sidebar each time JustSessions opens",
                isOn: Binding(
                    get: { tipsStore.showsTips },
                    set: { tipsStore.setShowsTips($0) }
                )
            )
            .toggleStyle(ThemedCheckboxToggleStyle())
            .accessibilityIdentifier("help.shows-random-tips")
            HelpPopoverButton(
                title: "Tips",
                explanation:
                    "The bottom of the sidebar shows a random tip about something you may not have tried. → shows another, and × hides it until JustSessions opens again."
            )
            .accessibilityIdentifier("help.help.random-tips")
        }
    }
}
