import SwiftUI

struct ReleaseNotesEntryView: View {
    let release: AppReleaseNotes
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "v\(release.version)").font(ThemeFont.detail.weight(.semibold))
                    Spacer()
                    Text(verbatim: release.formattedDate(locale: locale))
                        .font(ThemeFont.caption)
                        .foregroundStyle(ThemePalette.secondaryText)
                }
                Text(verbatim: release.title.localized(for: locale)).font(ThemeFont.heading)
            }
            ForEach(release.sections.indices, id: \.self) { sectionIndex in
                let section = release.sections[sectionIndex]
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.kind.title)
                        .font(ThemeFont.caption.weight(.semibold))
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
        .font(ThemeFont.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension AppReleaseNotes.Section.Kind {
    fileprivate var title: LocalizedStringKey {
        switch self {
        case .new: "New"
        case .improved: "Improved"
        case .fixed: "Fixed"
        }
    }
}
