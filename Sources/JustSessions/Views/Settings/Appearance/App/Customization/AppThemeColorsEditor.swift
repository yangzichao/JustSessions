import SwiftUI

struct AppThemeColorsEditor: View {
    @ObservedObject var appThemeStore: AppThemeStore

    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool
    @State private var editedVersionIsDark: Bool?
    @State private var refusedPick: RefusedThemeColorPick?

    init(appThemeStore: AppThemeStore) {
        self.appThemeStore = appThemeStore
        _isExpanded = State(initialValue: !appThemeStore.resolvedTheme.customization.isEmpty)
    }

    private var editsDarkVersion: Bool {
        editedVersionIsDark ?? (colorScheme == .dark)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ThemeSegmentedPicker(
                        "Version",
                        selection: Binding(
                            get: { editsDarkVersion },
                            set: { editedVersionIsDark = $0 }
                        ),
                        segments: [
                            ThemeSegment(value: false, title: Text("Light")),
                            ThemeSegment(value: true, title: Text("Dark")),
                        ]
                    )
                    .fixedSize()
                    Spacer(minLength: 0)
                    Button("Reset") {
                        appThemeStore.removeCustomization()
                        refusedPick = nil
                    }
                    .buttonStyle(QuietBorderedButtonStyle())
                    .controlSize(.small)
                    .disabled(appThemeStore.resolvedTheme.customization.isEmpty)
                    .help("Gives the theme back its own colors, light and dark.")
                }
                colorRows
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                ThemeDisclosureTitleButton(isExpanded: $isExpanded) {
                    Text("Customize colors")
                }
                HelpPopoverButton(
                    title: "Customize colors",
                    explanation:
                        "Changes the chosen theme's colors, in its light or dark version. Your changes stay with the theme when you choose another one. Text is made readable on your colors, so the text color can come out darker or lighter than you chose. Terminals that match the app theme take its background."
                )
                .accessibilityIdentifier("settings.help.customizeThemeColors")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: appThemeStore.theme) {
            refusedPick = nil
            if !appThemeStore.resolvedTheme.customization.isEmpty { isExpanded = true }
        }
    }

    private var colorRows: some View {
        let isDark = editsDarkVersion
        let colors = appThemeStore.resolvedTheme.colors(isDark: isDark)
        let changes = appThemeStore.resolvedTheme.customization.changes(isDark: isDark)
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(CustomizableThemeColor.allCases) { color in
                ThemeColorWellRow(
                    color: color,
                    value: changes[color] ?? color.drawnValue(in: colors),
                    isChanged: changes[color] != nil,
                    isAdjustedForReadability: changes[color].map { $0 != color.drawnValue(in: colors) } ?? false,
                    refusal: refusedPick == RefusedThemeColorPick(color: color, isDark: isDark)
                        ? RefusedThemeColorPick.message(isDark: isDark) : nil,
                    onChange: { value in
                        let isTaken = appThemeStore.setColor(value, for: color, isDark: isDark)
                        refusedPick = isTaken ? nil : RefusedThemeColorPick(color: color, isDark: isDark)
                    }
                )
            }
        }
    }
}

struct RefusedThemeColorPick: Equatable {
    let color: CustomizableThemeColor
    let isDark: Bool

    static func message(isDark: Bool) -> LocalizedStringKey {
        isDark
            ? "Text can't stay readable on that color. Choose a darker one."
            : "Text can't stay readable on that color. Choose a lighter one."
    }
}
