import SwiftUI

extension View {
    /// Lets the row be dragged among the pinned rows of its scope; see `SidebarPinDrag`. Once the pointer has moved a
    /// few points, the drag takes over from the row's buttons, so letting go doesn't click the row, while a click still
    /// does. `onEnded` comes when the drag ends or is cancelled, and `onCancelled` when the row goes away mid-drag, so a
    /// drag never stays half done. While dragged, the
    /// row fades, `ghost` follows the pointer, and the landing line shows `landingLineOffset` below the row's top.
    /// Both are drawn by the dragged row, over the rows they pass, the line over the ghost.
    func sidebarPinDragSource<Ghost: View>(
        isDragged: Bool,
        translation: CGFloat,
        landingLineOffset: CGFloat?,
        landingLineLeadingInset: CGFloat,
        onChanged: @escaping (_ pointerY: CGFloat) -> Void,
        onEnded: @escaping () -> Void,
        onCancelled: @escaping () -> Void,
        @ViewBuilder ghost: () -> Ghost
    ) -> some View {
        modifier(SidebarPinDragGesture(
            isDragged: isDragged,
            translation: translation,
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
    /// How far the pointer moves before a press on a row becomes a drag.
    static let minimumDistance: CGFloat = 4
    /// How long the rows take to settle into their new order once the dragged one is let go.
    static let dropAnimation: Animation = .easeOut(duration: 0.15)
    static let draggedRowOpacity: Double = 0.4
    /// See-through, as a macOS drag image is, so the rows around where it would land still show.
    static let ghostOpacity: Double = 0.7
}

private struct SidebarPinDragGesture<Ghost: View>: ViewModifier {
    let isDragged: Bool
    let translation: CGFloat
    let landingLineOffset: CGFloat?
    let landingLineLeadingInset: CGFloat
    let onChanged: (CGFloat) -> Void
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
                        ghost
                            .background {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(ThemePalette.raisedSurface)
                                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                            }
                            .opacity(SidebarPinDragMetrics.ghostOpacity)
                            .offset(y: translation)
                        if let landingLineOffset {
                            SidebarPinLandingLine(leadingInset: landingLineLeadingInset)
                                .offset(y: landingLineOffset - SidebarPinLandingLine.thickness / 2)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            // Over the rows after it, which the ghost and the line pass over.
            .zIndex(isDragged ? 1 : 0)
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: SidebarPinDragMetrics.minimumDistance,
                    coordinateSpace: .named(SidebarRowFrames.coordinateSpace)
                )
                .updating($isDragging) { _, isDragging, _ in isDragging = true }
                .onChanged { onChanged($0.location.y) }
            )
            .onChange(of: isDragging) { _, isDragging in
                if !isDragging { onEnded() }
            }
            .onDisappear {
                if isDragged { onCancelled() }
            }
    }
}
