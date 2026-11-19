import SwiftUI

struct HostCheckProgressView: View {
    let host: String
    let step: HostCheckStep
    let stepStartedAt: Date
    let checksTabFolder: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Checking \(host)…")
                .font(ThemeFont.body.weight(.medium))
            ProgressView(value: Double(step.rawValue), total: Double(HostCheckStep.allCases.count))
                .progressViewStyle(.linear)
                .controlSize(.small)
                .accessibilityLabel("Checking \(host)")
                .accessibilityValue("Step \(step.rawValue + 1) of \(HostCheckStep.allCases.count)")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(HostCheckStep.allCases, id: \.self) { eachStep in
                    stepRow(eachStep)
                    if eachStep != HostCheckStep.allCases.last {
                        ThemeDivider()
                    }
                }
            }
            .background(ThemePalette.raisedSurface, in: RoundedRectangle(.card))
            .overlay(RoundedRectangle(.card).stroke(ThemePalette.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(.card))
            Spacer(minLength: 0)
        }
    }

    private func stepRow(_ rowStep: HostCheckStep) -> some View {
        HStack(spacing: 8) {
            Group {
                if rowStep < step {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(ThemePalette.secondaryText)
                } else if rowStep == step {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(ThemePalette.tertiaryText)
                }
            }
            .font(ThemeFont.body)
            .frame(width: InterfaceScale.points(16), height: InterfaceScale.points(16))
            Text(title(of: rowStep))
                .font(ThemeFont.callout)
                .foregroundStyle(rowStep > step ? ThemePalette.tertiaryText : ThemePalette.ink)
            Spacer(minLength: 8)
            if rowStep == step {
                Text(timerInterval: stepStartedAt...Date.distantFuture, countsDown: false)
                    .font(ThemeFont.detail.monospacedDigit())
                    .foregroundStyle(ThemePalette.tertiaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityValue(rowStep < step ? Text("Done") : rowStep == step ? Text("Running") : Text("Waiting"))
    }

    private func title(of rowStep: HostCheckStep) -> LocalizedStringKey {
        switch rowStep {
        case .logIn: "Logging in to \(host)"
        case .shellStartup: "Checking its shell startup"
        case .cliLookup: "Looking up each CLI"
        case .hostCommand:
            checksTabFolder
                ? "Asking about tmux, rsync, each CLI's version, and the tab's folder"
                : "Asking about tmux, rsync, and each CLI's version"
        }
    }
}
