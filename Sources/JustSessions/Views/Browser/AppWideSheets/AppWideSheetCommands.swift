import SwiftUI

/// Settings… (⌘,) opens General; JustSessions Help opens Help in the same Settings sheet. Take the Tour
/// starts the active workspace window's onboarding tour. Send Feedback opens the website's form in the browser.
struct AppWideSheetCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.startOnboardingTour) private var startOnboardingTour

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(AppLocalization.string("Settings…", language: languageStore.language)) { show(.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button(AppLocalization.string("JustSessions Help", language: languageStore.language),
                   systemImage: "questionmark.circle") { show(.help) }
            Button(AppLocalization.string("Take the Tour", language: languageStore.language)) { startOnboardingTour?() }
                .disabled(startOnboardingTour == nil)
            Button(AppLocalization.string("Release notes", language: languageStore.language)) { show(.releaseNotes) }
            Divider()
            Link("Send Feedback", destination: FeedbackLinks.formURL(for: .current))
                .environment(\.locale, languageStore.locale)
            Link("JustSessions Website", destination: AppLinks.websiteURL)
                .environment(\.locale, languageStore.locale)
        }
    }

    private func show(_ sheet: AppWideSheet) {
        AppWideSheetPresenters.show(sheet) { openWindow(id: "workspace") }
    }
}
