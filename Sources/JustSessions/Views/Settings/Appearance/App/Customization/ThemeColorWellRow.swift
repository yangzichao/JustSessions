import AppKit
import SwiftUI

struct ThemeColorWellRow: View {
    let color: CustomizableThemeColor
    let value: UInt32
    let isChanged: Bool
    let isAdjustedForReadability: Bool
    let refusal: LocalizedStringKey?
    let onChange: (UInt32?) -> Void

    var body: some View {
        GridRow {
            Text(color.localizedTitle)
            HStack(spacing: 6) {
                ColorPicker(
                    color.localizedTitle,
                    selection: Binding(
                        get: { Color(nsColor: NSColor(hexValue: value)) },
                        set: { newColor in
                            guard let hexValue = NSColor(newColor).sRGBHexValue else { return }
                            onChange(hexValue)
                        }
                    ), supportsOpacity: false
                )
                .labelsHidden()
                Button {
                    onChange(nil)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(ThemeFont.detail)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .frame(width: InterfaceScale.points(20), height: InterfaceScale.points(20))
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
                .font(ThemeFont.caption)
                .foregroundStyle(ThemePalette.warningText)
                .fixedSize(horizontal: false, vertical: true)
        } else if isAdjustedForReadability {
            Text("Adjusted to stay readable")
                .font(ThemeFont.caption)
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
}
