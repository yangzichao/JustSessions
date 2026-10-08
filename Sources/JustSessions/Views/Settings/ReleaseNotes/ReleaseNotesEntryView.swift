import SwiftUI

struct ReleaseNotesEntryView: View {
    let release: AppReleaseNotes
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "v\(release.version)").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(verbatim: release.formattedDate(locale: locale))
                        .font(.caption)
                        .foregroundStyle(ThemePalette.secondaryText)
                }
                Text(verbatim: release.title.localized(for: locale)).font(.headline)
            }
            ForEach(release.sections.indices, id: \.self) { sectionIndex in
                let section = release.sections[sectionIndex]
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ThemePalette.secondaryText)
                    ForEach(section.items.indices, id: \.self) { itemIndex in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(verbatim: "•")
                            Text(verbatim: section.items[itemIndex].localized(for: locale))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private extension AppReleaseNotes.Section.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .new: "New"
        case .improved: "Improved"
        case .fixed: "Fixed"
        }
    }
}
