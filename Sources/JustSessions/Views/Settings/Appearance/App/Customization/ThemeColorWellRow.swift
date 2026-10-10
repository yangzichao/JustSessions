import AppKit
import SwiftUI

/// One color of the theme you can change: its name, a color well, a button that gives it back the theme's own color
/// once changed, and a note when the color was made readable or a pick was refused. A row of the editor's grid.
struct ThemeColorWellRow: View {
    let color: CustomizableThemeColor
    let value: UInt32
    let isChanged: Bool
    let isAdjustedForReadability: Bool
    let refusal: LocalizedStringKey?
    /// Nil gives the color back the theme's own.
    let onChange: (UInt32?) -> Void

    var body: some View {
        GridRow {
            Text(color.localizedTitle)
            HStack(spacing: 6) {
                ColorPicker(color.localizedTitle, selection: Binding(
                    get: { Color(nsColor: NSColor(hexValue: value)) },
                    set: { newColor in
                        guard let hexValue = NSColor(newColor).sRGBHexValue else { return }
                        onChange(hexValue)
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                Button {
                    onChange(nil)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11))
                        .foregroundStyle(ThemePalette.secondaryText)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(ThemePlainButtonStyle())
                .help("Use the theme's own color")
                .accessibilityLabel("Use the theme's own color")
                .opacity(isChanged ? 1 : 0)
                .disabled(!isChanged)
                .accessibilityHidden(!isChanged)
                note
            }
        }
    }

    @ViewBuilder private var note: some View {
        if let refusal {
            Text(refusal)
                .font(.caption)
                .foregroundStyle(ThemePalette.warningText)
                .fixedSize(horizontal: false, vertical: true)
        } else if isAdjustedForReadability {
            Text("Adjusted to stay readable")
                .font(.caption)
                .foregroundStyle(ThemePalette.tertiaryText)
        }
    }
}

extension CustomizableThemeColor {
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .contentSurface: "Background"
        case .sidebarSurface: "Sidebar"
        case .raisedSurface: "Fields and buttons"
        case .userMessageSurface: "Your messages"
        case .ink: "Text and accents"
        }
    }

    /// Why a pick was refused: a surface of the wrong lightness for the version, or one text can't be made readable on.
    func refusalMessage(isDark: Bool) -> LocalizedStringKey {
        guard isSurface else { return "Text can't be made readable with that color." }
        return isDark
            ? "Text can't stay readable on that color. Choose a darker one."
            : "Text can't stay readable on that color. Choose a lighter one."
    }
}
