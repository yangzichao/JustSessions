import SwiftUI

struct NewSessionKindPicker: View {
    @Binding var selection: NewSessionKind
    let providers: [ConversationProvider]
    let noCLIFoundMessage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Tool")
            VStack(alignment: .leading, spacing: 10) {
                if providers.isEmpty {
                    Label(noCLIFoundMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(ThemePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ThemeSegmentedPicker(
                        "Tool", selection: $selection,
                        segments: providers.map { provider in
                            ThemeSegment(value: NewSessionKind.cli(provider), title: Text(provider.rawValue))
                        })
                }
                HStack(spacing: 10) {
                    ThemeSegmentedPicker(
                        "Terminal", selection: $selection,
                        segments: [
                            ThemeSegment(value: NewSessionKind.plainTerminal, title: Text("Terminal"))
                        ]
                    )
                    .fixedSize()
                    Text("Your login shell, with no CLI")
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                }
            }
        }
    }
}
