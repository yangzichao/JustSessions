import SwiftUI

struct TerminalTabTitle: View {
    private let title: Text

    init(title: String) {
        self.title = Text(verbatim: title)
    }

    init(localizedTitle: LocalizedStringKey) {
        self.title = Text(localizedTitle)
    }

    private static let fadeWidth: CGFloat = 18

    var body: some View {
        ViewThatFits(in: .horizontal) {
            title
                .lineLimit(1)
            title
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
