import SwiftUI

struct FeedbackForm: View {
    @Binding var draft: FeedbackDraft
    let versionInformation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeedbackKindPicker(selection: $draft.kind)

            VStack(alignment: .leading, spacing: 6) {
                Text("Title").font(.subheadline.weight(.medium))
                TextField("A short summary", text: $draft.title)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .accessibilityIdentifier("feedback.title")
                if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count > 200 {
                    Text("Use 200 characters or fewer for the title.")
                        .font(.caption).foregroundStyle(ThemePalette.warning)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Details").font(.subheadline.weight(.medium))
                Text(draft.kind.guidance)
                    .font(.caption).foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                TextEditor(text: $draft.details)
                    .font(.body)
                    .foregroundStyle(ThemePalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: 160)
                    .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThemePalette.hairline))
                    .accessibilityLabel("Feedback details")
                    .accessibilityIdentifier("feedback.details")
            }

            Toggle("Include app and macOS versions", isOn: $draft.includesVersionInformation)
                .toggleStyle(ThemedCheckboxToggleStyle())
                .font(.subheadline)
            if draft.includesVersionInformation {
                Text(versionInformation)
                    .font(.caption).foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .foregroundStyle(ThemePalette.ink)
    }
}
