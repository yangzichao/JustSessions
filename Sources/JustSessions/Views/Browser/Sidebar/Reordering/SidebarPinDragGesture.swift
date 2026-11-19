import SwiftUI

extension View {
    func sidebarPinDragSource<Ghost: View>(
        isDragged: Bool,
        ghostOffset: CGFloat?,
        landingLineOffset: CGFloat?,
        landingLineLeadingInset: CGFloat,
        onChanged: @escaping (_ pointer: CGPoint) -> Void,
        onEnded: @escaping () -> Void,
        onCancelled: @escaping () -> Void,
        @ViewBuilder ghost: () -> Ghost
    ) -> some View {
        modifier(
            SidebarPinDragGesture(
                isDragged: isDragged,
                ghostOffset: ghostOffset,
                landingLineOffset: landingLineOffset,
                landingLineLeadingInset: landingLineLeadingInset,
                onChanged: onChanged,
                onEnded: onEnded,
                onCancelled: onCancelled,
                ghost: ghost()
            ))
    }
}

enum SidebarPinDragMetrics {
    static let minimumDistance: CGFloat = 4
    static let dropAnimation = ThemeMotion.slide
    static let draggedRowOpacity: Double = 0.4
    static let ghostOpacity: Double = 0.7
}

private struct SidebarPinDragGesture<Ghost: View>: ViewModifier {
    let isDragged: Bool
    let ghostOffset: CGFloat?
    let landingLineOffset: CGFloat?
    let landingLineLeadingInset: CGFloat
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void
    let onCancelled: () -> Void
    let ghost: Ghost

    /// SwiftUI resets it as the drag ends, whether let go or cancelled; a gesture's own `onEnded` misses a cancel.
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            .opacity(isDragged ? SidebarPinDragMetrics.draggedRowOpacity : 1)
            .overlay(alignment: .top) {
                if isDragged {
                    ZStack(alignment: .top) {
                        if let ghostOffset {
                            ghost
                                .background {
                                    RoundedRectangle(.control)
                                        .fill(ThemePalette.raisedSurface)
                                        .themeShadow(.floating)
                                }
                                .opacity(SidebarPinDragMetrics.ghostOpacity)
                                .offset(y: ghostOffset)
                        }
                        if let landingLineOffset {
                            SidebarPinLandingLine(leadingInset: landingLineLeadingInset)
                                .offset(y: landingLineOffset - SidebarPinLandingLine.thickness / 2)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .zIndex(isDragged ? 1 : 0)
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: SidebarPinDragMetrics.minimumDistance,
                    coordinateSpace: .named(SidebarRowFrames.coordinateSpace)
                )
                .updating($isDragging) { _, isDragging, _ in isDragging = true }
                .onChanged { onChanged($0.location) }
            )
            .onChange(of: isDragging) { _, isDragging in
                if !isDragging { onEnded() }
            }
            .onDisappear {
                if isDragged { onCancelled() }
            }
    }
}
