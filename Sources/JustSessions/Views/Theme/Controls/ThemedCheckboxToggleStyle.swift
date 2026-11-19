import SwiftUI

struct ThemedCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(.checkbox)
                    .fill(configuration.isOn ? ThemePalette.ink : ThemePalette.raisedSurface)
                    .overlay(RoundedRectangle(.checkbox).strokeBorder(ThemePalette.hairline))
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark")
                                .font(ThemeFont.glyph(.control, weight: .bold))
                                .foregroundStyle(ThemePalette.inkForeground)
                        }
                    }
                    .frame(width: InterfaceScale.points(16), height: InterfaceScale.points(16))
                configuration.label.foregroundStyle(ThemePalette.ink)
            }
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.checkbox)
        }
    }
}
