import SwiftUI

extension View {
    /// Shows Settings or Help as a sheet on this workspace window while `sheet` holds one. The sidebar opens them
    /// through `showAppWideSheet`, the app menu through `AppWideSheetPresenters`, and a click outside closes them.
    func showsAppWideSheets(
        _ sheet: Binding<AppWideSheet?>,
        onCheckForUpdates: @escaping () -> Void
    ) -> some View {
        environment(\.showAppWideSheet, ShowAppWideSheetAction { sheet.wrappedValue = $0 })
            .background(AppWideSheetWindowRegistration(sheet: sheet))
            .sheet(item: sheet) { shownSheet in
                switch shownSheet {
                case .settings: SettingsSheet(onCheckForUpdates: onCheckForUpdates)
                case .help: HelpView()
                }
            }
            .dismissesOnClickOutside(item: sheet)
            .onAppear {
                if let sheetForThisWindow = AppWideSheetPresenters.takeSheetForNewWorkspaceWindow() {
                    sheet.wrappedValue = sheetForThisWindow
                }
            }
    }
}
