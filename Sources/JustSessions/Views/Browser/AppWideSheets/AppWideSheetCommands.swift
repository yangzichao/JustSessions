import SwiftUI

/// Settings… (⌘,) opens General; JustSessions Help opens Help & feedback in the same Settings sheet.
struct AppWideSheetCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(AppLocalization.string("Settings…", language: languageStore.language)) { show(.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button(AppLocalization.string("JustSessions Help", language: languageStore.language),
                   systemImage: "questionmark.circle") { show(.help) }
            Divider()
            Link("JustSessions Website", destination: AppLinks.websiteURL)
                .environment(\.locale, languageStore.locale)
        }
    }

    private func show(_ sheet: AppWideSheet) {
        AppWideSheetPresenters.show(sheet) { openWindow(id: "workspace") }
    }
}
