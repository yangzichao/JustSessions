/// One Settings sheet per workspace window; the menu can select a page while the sheet stays open.
struct AppWideSheet: Identifiable, Equatable {
    let selectedSettingsTab: SettingsTab

    static let settings = AppWideSheet(selectedSettingsTab: .general)
    static let help = AppWideSheet(selectedSettingsTab: .help)

    var id: String { "settings" }
}
