import SwiftUI

struct HelpMoreFeatures: View {
    var body: some View {
        Text("Also: search, pin, rename, and export sessions as Markdown. Claude Code and Codex on this Mac can notify you when they finish or need input. Features vary by CLI.")
            .font(.callout)
            .foregroundStyle(ThemePalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
