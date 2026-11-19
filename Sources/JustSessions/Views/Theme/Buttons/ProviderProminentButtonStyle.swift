import SwiftUI

struct ProviderProminentButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ThemeFont.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: InterfaceScale.points(28))
            .background(RoundedRectangle(.card).fill(tint))
            .contentShape(RoundedRectangle(.card))
            .modifier(ThemeButtonPressFeedback(isPressed: configuration.isPressed))
    }
}
