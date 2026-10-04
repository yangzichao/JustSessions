import SwiftUI

/// Shows Settings or Help as a sheet on the workspace window this view is in.
struct ShowAppWideSheetAction {
    let show: @MainActor (AppWideSheet) -> Void

    @MainActor func callAsFunction(_ sheet: AppWideSheet) {
        show(sheet)
    }
}

extension EnvironmentValues {
    @Entry var showAppWideSheet = ShowAppWideSheetAction { _ in }
}
