import SwiftUI

extension View {
    func showsAppWideSheets(
        _ sheet: Binding<AppWideSheet?>,
        store: ConversationStore,
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
                    store: store,
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
