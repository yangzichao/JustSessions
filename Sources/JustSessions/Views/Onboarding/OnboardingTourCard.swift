import SwiftUI

struct OnboardingTourCard: View {
    static var width: CGFloat { InterfaceScale.points(280) }

    let stop: OnboardingTourStop
    let stepNumber: Int
    let stepCount: Int
    let onNext: @MainActor () -> Void
    let onEnd: @MainActor () -> Void

    private var isLastStep: Bool {
        stepNumber == stepCount
    }

    private var nextTitle: LocalizedStringKey {
        if stepCount == 1 { return "Got it" }
        return isLastStep ? "Done" : "Next"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if stepCount > 1 {
                Text("\(stepNumber) of \(stepCount)")
                    .font(ThemeFont.detail.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(ThemePalette.secondaryText)
            }
            Text(stop.title)
                .font(ThemeFont.heading)
            Text(stop.message)
                .font(ThemeFont.callout)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if !isLastStep {
                    Button("Skip", action: onEnd)
                        .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 6, verticalPadding: 4))
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .accessibilityIdentifier("onboarding-tour.skip")
                }
                Spacer(minLength: 0)
                Button(nextTitle, action: onNext)
                    .buttonStyle(ThemeProminentButtonStyle())
                    .accessibilityIdentifier("onboarding-tour.next")
            }
            .padding(.top, 8)
        }
        .foregroundStyle(ThemePalette.ink)
        .padding(16)
        .frame(width: Self.width, alignment: .leading)
    }
}
