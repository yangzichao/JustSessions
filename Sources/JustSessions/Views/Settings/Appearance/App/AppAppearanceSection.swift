import SwiftUI

struct AppAppearanceSection: View {
    let appAppearanceStore: AppAppearanceStore
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore
    var interfaceSizeStore = InterfaceSizeStore.shared

    var body: some View {
        GridRow {
            SettingsSectionHeading("App")
        }
        GridRow(alignment: .top) {
            Text("Appearance").levelWithThumbnails()
            AppAppearanceModePicker(appAppearanceStore: appAppearanceStore)
        }
        GridRow(alignment: .top) {
            Text("Theme").levelWithThumbnails()
            VStack(alignment: .leading, spacing: 14) {
                AppThemePicker(appThemeStore: appThemeStore, terminalAppearanceStore: terminalAppearanceStore)
                AppThemeColorsEditor(appThemeStore: appThemeStore)
            }
        }
        GridRow {
            Text("Interface size")
            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { interfaceSizeStore.scale },
                        set: { interfaceSizeStore.setScale($0) }
                    ), in: InterfaceSizeStore.scaleRange, step: InterfaceSizeStore.scaleStep
                )
                .accessibilityLabel("Interface size")
                Text(interfaceSizeStore.scale, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .frame(width: InterfaceScale.points(42), alignment: .trailing)
            }
        }
    }
}
