import SwiftUI

extension View {
    /// Shows Settings while `sheet` holds a selected page. Help opens its Help tab in the same sheet.
    func showsAppWideSheets(
        _ sheet: Binding<AppWideSheet?>,
        onCheckForUpdates: @escaping () -> Void
    ) -> some View {
        environment(\.showAppWideSheet, ShowAppWideSheetAction { sheet.wrappedValue = $0 })
            .background(AppWideSheetWindowRegistration(sheet: sheet))
            .sheet(item: sheet) { _ in
                SettingsSheet(
                    selectedTab: Binding(
                        get: { sheet.wrappedValue?.selectedSettingsTab ?? .general },
                        set: { sheet.wrappedValue = AppWideSheet(selectedSettingsTab: $0) }
                    ),
                    onCheckForUpdates: onCheckForUpdates
                )
            }
            .dismissesOnClickOutside(item: sheet)
            .onAppear {
                if let sheetForThisWindow = AppWideSheetPresenters.takeSheetForNewWorkspaceWindow() {
                    sheet.wrappedValue = sheetForThisWindow
                }
            }
    }
}
