import SwiftUI

struct ThemePlainButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 0
    var verticalPadding: CGFloat = 0
    var cornerRadius: ThemeCornerRadius? = .control
    var showsHover = true

    func makeBody(configuration: Configuration) -> some View {
        ThemePlainButtonSurface(
            label: configuration.label,
            isPressed: configuration.isPressed,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            cornerRadius: cornerRadius,
            showsHover: showsHover
        )
    }
}

private struct ThemePlainButtonSurface<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: ThemeCornerRadius?
    let showsHover: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var shape: AnyShape {
        cornerRadius.map { AnyShape(RoundedRectangle($0)) } ?? AnyShape(Circle())
    }

    var body: some View {
        label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                if isEnabled && showsHover && isHovered {
                    shape.fill(ThemePalette.hoverFill)
                }
            }
            .overlay {
                if isEnabled && isPressed {
                    shape.fill(ThemePalette.pressedFill).allowsHitTesting(false)
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
    }
}
