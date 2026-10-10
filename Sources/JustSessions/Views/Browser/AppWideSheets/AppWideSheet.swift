/// One Settings sheet per workspace window; the menu can select a page while the sheet stays open.
struct AppWideSheet: Identifiable, Equatable {
    let selectedSettingsTab: SettingsTab

    static let settings = AppWideSheet(selectedSettingsTab: .general)
    static let help = AppWideSheet(selectedSettingsTab: .help)
    static let releaseNotes = AppWideSheet(selectedSettingsTab: .releaseNotes)
    static let feedback = AppWideSheet(selectedSettingsTab: .feedback)

    var id: String { "settings" }
}
