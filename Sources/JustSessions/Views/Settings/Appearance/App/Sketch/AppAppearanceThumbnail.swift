import SwiftUI

struct AppAppearanceThumbnail: View {
    let mode: AppAppearanceMode

    var body: some View {
        switch mode {
        case .system:
            LightAndDarkWindowSketch()
        case .light:
            AppWindowSketch().environment(\.colorScheme, .light)
        case .dark:
            AppWindowSketch().environment(\.colorScheme, .dark)
        }
    }
}
