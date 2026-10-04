import SwiftUI

/// The window sketch in one mode's colors. System shows the light and dark sketches side by side, split on a slant.
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
