import SwiftUI

/// The × inside a tab, with a round fill under the pointer as in Chrome.
struct TerminalTabCloseButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 16)
                .background {
                    if isHovered { Circle().fill(ThemeColor(role: .line, opacity: 0.12)) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("End and close this terminal")
        .accessibilityLabel("Close \(title)")
    }
}
