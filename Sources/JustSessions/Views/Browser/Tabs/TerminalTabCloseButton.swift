import SwiftUI

struct TerminalTabCloseButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(ThemeFont.glyph(.small, weight: .bold))
                .frame(width: InterfaceScale.points(16), height: InterfaceScale.points(16))
                .contentShape(Circle())
        }
        .buttonStyle(ThemePlainButtonStyle(cornerRadius: nil))
        .help("End and close this terminal")
        .accessibilityLabel("Close \(title)")
    }
}
