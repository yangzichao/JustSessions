import SwiftUI

struct SidebarMessageSearchProgress: View {
    @ObservedObject var indexer: SessionMessageIndexer

    var body: some View {
        if let progress = indexer.progress {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Searching messages… \(progress.readCount) of \(progress.totalCount)")
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .font(ThemeFont.detail)
            .foregroundStyle(ThemePalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
        }
    }
}
