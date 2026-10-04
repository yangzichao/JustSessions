import SwiftUI

/// The × inside a tab, with a round fill under the pointer as in Chrome.
struct TerminalTabCloseButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 16)
                .contentShape(Circle())
        }
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: 8))
        .help("End and close this terminal")
        .accessibilityLabel("Close \(title)")
    }
}
