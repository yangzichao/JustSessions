import SwiftUI

enum ThumbnailChoiceMetrics {
    static let thumbnailSize = CGSize(width: 112, height: 72)
    static let ringInset: CGFloat = 3
    static let buttonWidth = thumbnailSize.width + 2 * ringInset
    static let thumbnailMidY = ringInset + thumbnailSize.height / 2
}

extension View {
    func levelWithThumbnails() -> some View {
        alignmentGuide(.top) { dimensions in dimensions[VerticalAlignment.center] - ThumbnailChoiceMetrics.thumbnailMidY }
    }
}

struct ThumbnailChoiceButton<Thumbnail: View>: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let onSelect: () -> Void
    var detail: LocalizedStringKey?
    @ViewBuilder let thumbnail: () -> Thumbnail

    @State private var isHovered = false

    private var thumbnailShape: RoundedRectangle {
        RoundedRectangle(.control)
    }

    private var ringShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ThemeCornerRadius.control.rawValue + ThumbnailChoiceMetrics.ringInset, style: .continuous)
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
                    .font(ThemeFont.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(ThemePalette.ink) : AnyShapeStyle(ThemePalette.secondaryText))
                if let detail {
                    Text(detail)
                        .font(ThemeFont.caption)
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
