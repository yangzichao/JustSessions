import SwiftUI

/// Settings… (⌘,) opens General; JustSessions Help opens Help & feedback in the same Settings sheet. Take the Tour
/// starts the active workspace window's onboarding tour.
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
            Divider()
            Link("JustSessions Website", destination: AppLinks.websiteURL)
                .environment(\.locale, languageStore.locale)
        }
    }

    private func show(_ sheet: AppWideSheet) {
        AppWideSheetPresenters.show(sheet) { openWindow(id: "workspace") }
    }
}
