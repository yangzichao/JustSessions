import SwiftUI

/// Blank space dismisses batch selection; Escape belongs to this list only while it has keyboard focus.
struct SidebarSelectionScrollView<Content: View>: View {
    @FocusState.Binding var isFocused: Bool
    let onDismissSelection: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content()
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .topLeading)
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isFocused = true
                                onDismissSelection()
                            }
                    }
            }
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onExitCommand(perform: onDismissSelection)
        }
    }
}
