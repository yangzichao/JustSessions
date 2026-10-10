import SwiftUI

/// The size of a `ThumbnailChoiceButton`'s thumbnail, and where it sits in the button.
enum ThumbnailChoiceMetrics {
    static let thumbnailSize = CGSize(width: 112, height: 72)
    /// The gap between the thumbnail and the ring drawn around it.
    static let ringInset: CGFloat = 3
    static let buttonWidth = thumbnailSize.width + 2 * ringInset
    static let thumbnailMidY = ringInset + thumbnailSize.height / 2
}

extension View {
    /// Puts a label in a top-aligned grid row level with the middle of the first thumbnails beside it.
    func levelWithThumbnails() -> some View {
        alignmentGuide(.top) { dimensions in dimensions[VerticalAlignment.center] - ThumbnailChoiceMetrics.thumbnailMidY }
    }
}

/// A choice drawn as a thumbnail above its name, ringed in ink while chosen and faintly under the pointer.
struct ThumbnailChoiceButton<Thumbnail: View>: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let onSelect: () -> Void
    /// A short note under the name, such as that the theme has your changes.
    var detail: LocalizedStringKey?
    @ViewBuilder let thumbnail: () -> Thumbnail

    @State private var isHovered = false

    private var thumbnailShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }

    private var ringShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
    }

    private var ringStyle: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(ThemePalette.ink) }
        return isHovered ? AnyShapeStyle(ThemePalette.ink.opacity(0.2)) : AnyShapeStyle(Color.clear)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                thumbnail()
                    .frame(width: ThumbnailChoiceMetrics.thumbnailSize.width, height: ThumbnailChoiceMetrics.thumbnailSize.height)
                    .clipShape(thumbnailShape)
                    .overlay(thumbnailShape.strokeBorder(ThemePalette.hairline))
                    .padding(ThumbnailChoiceMetrics.ringInset)
                    .overlay(ringShape.strokeBorder(ringStyle, lineWidth: 2))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(ThemePalette.secondaryText))
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(ThemePalette.tertiaryText)
                        .padding(.top, -4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ThemePressButtonStyle())
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(detail.map { Text($0) } ?? Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
