import SwiftUI

struct ShowAppWideSheetAction {
    let show: @MainActor (AppWideSheet) -> Void

    @MainActor func callAsFunction(_ sheet: AppWideSheet) {
        show(sheet)
    }
}

extension EnvironmentValues {
    @Entry var showAppWideSheet = ShowAppWideSheetAction { _ in }
}
