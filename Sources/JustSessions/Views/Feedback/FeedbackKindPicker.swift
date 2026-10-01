import SwiftUI

struct FeedbackKindPicker: View {
    @Binding var selection: FeedbackKind

    var body: some View {
        HStack(spacing: 10) {
            Text("Feedback type")
            Menu {
                Picker("Feedback type", selection: $selection) {
                    ForEach(FeedbackKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Text(selection.rawValue)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            .foregroundStyle(ThemePalette.ink)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ThemePalette.hairline))
            .accessibilityLabel("Feedback type")
            .accessibilityValue(selection.rawValue)
            .accessibilityIdentifier("feedback.kind")
        }
    }
}
