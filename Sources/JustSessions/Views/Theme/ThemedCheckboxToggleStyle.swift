import SwiftUI

/// An inline checkbox whose checked and unchecked surfaces follow the app theme.
struct ThemedCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(configuration.isOn ? ThemePalette.ink : ThemePalette.raisedSurface)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(ThemePalette.hairline))
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ThemePalette.inkForeground)
                        }
                    }
                    .frame(width: 16, height: 16)
                configuration.label.foregroundStyle(ThemePalette.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.checkbox)
        }
    }
}
