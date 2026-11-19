import SwiftUI

struct TerminalColorIntensitySlider: View {
    @ObservedObject var appearanceStore: TerminalAppearanceStore

    var body: some View {
        let percentRange = TerminalColorIntensity.percentRange
        HStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { Double(appearanceStore.preferences.colorIntensityPercent) },
                    set: { appearanceStore.setColorIntensityPercent(Int($0.rounded())) }
                ), in: Double(percentRange.lowerBound)...Double(percentRange.upperBound), step: Double(TerminalColorIntensity.percentStep)
            )
            .accessibilityLabel("Color intensity")
            Text(Double(appearanceStore.preferences.colorIntensityPercent) / 100, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
        .help("Makes the 16 colors that shells and many CLIs pick from stronger or softer. Colors a program sets exactly stay as they are.")
    }
}
