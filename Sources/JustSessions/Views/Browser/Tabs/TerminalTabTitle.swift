import SwiftUI

/// A tab's title, filling the room the tab leaves it. A title too long for that room fades out at its end, as in
/// Chrome, instead of ending in an ellipsis, which would take up much of a narrow tab.
struct TerminalTabTitle: View {
    let title: String

    private static let fadeWidth: CGFloat = 18

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(title)
                .lineLimit(1)
            Text(title)
                .lineLimit(1)
                .fixedSize()
                // A minimum lets the frame narrow below the title's own width, which then runs past the frame's end.
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .mask {
                    HStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: Self.fadeWidth)
                    }
                }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}
