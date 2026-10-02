import SwiftUI

/// Three short options read best side by side. Drawn with theme colors because the native
/// segmented control fills the selection with the system accent instead of the chosen theme.
struct FeedbackKindPicker: View {
    @Binding var selection: FeedbackKind

    @Namespace private var selectedSegmentNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Type").font(.subheadline.weight(.medium))
            HStack(spacing: 2) {
                ForEach(FeedbackKind.allCases) { kind in
                    segment(for: kind)
                }
            }
            .padding(2)
            .background(ThemePalette.trackFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Feedback type")
            .accessibilityIdentifier("feedback.kind")
        }
    }

    private func segment(for kind: FeedbackKind) -> some View {
        let isSelected = selection == kind

        return Button {
            withAnimation(.snappy(duration: 0.2)) { selection = kind }
        } label: {
            Text(kind.rawValue)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ThemePalette.ink : ThemePalette.secondaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .contentShape(Rectangle())
                .background {
                    if isSelected {
                        // The hairline keeps the selection visible in dark themes, where the raised surface
                        // is close to the track.
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(ThemePalette.raisedSurface)
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(ThemePalette.hairline))
                            .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
                            .matchedGeometryEffect(id: "selectedSegment", in: selectedSegmentNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
