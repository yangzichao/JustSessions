import SwiftUI

struct HostFixAgentGuideSectionToggles: View {
    @Binding var selection: Set<JustSessionsGuideSection>

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
            ForEach(JustSessionsGuideSection.all) { section in
                Toggle(
                    isOn: Binding(
                        get: { selection.contains(section) },
                        set: { isOn in
                            if isOn { selection.insert(section) } else { selection.remove(section) }
                        }
                    )
                ) {
                    Text(verbatim: section.heading)
                        .font(ThemeFont.callout)
                        .lineLimit(1)
                }
                .toggleStyle(ThemedCheckboxToggleStyle())
                .help(section.fileName)
            }
        }
    }
}
