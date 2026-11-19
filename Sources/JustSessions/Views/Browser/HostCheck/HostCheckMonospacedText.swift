import SwiftUI

struct HostCheckMonospacedText: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(ThemeFont.detail.monospaced())
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(ThemePalette.contentSurface, in: RoundedRectangle(.control))
            .overlay(RoundedRectangle(.control).stroke(ThemePalette.hairline, lineWidth: 1))
    }
}
