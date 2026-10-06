import SwiftUI

/// At the top of the project list while a search reads sessions it has not read before, or since they changed.
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
            .font(.system(size: 11))
            .foregroundStyle(ThemePalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
        }
    }
}
