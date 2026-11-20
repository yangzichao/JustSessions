import CoreGraphics

struct ConversationMapLayout: Equatable {
    enum Ink: Int, CaseIterable, Comparable {
        case toolRun, assistant, user

        init(_ kind: ConversationOutline.Block.Kind) {
            switch kind {
            case .user, .image: self = .user
            case .assistant: self = .assistant
            case .toolRun: self = .toolRun
            }
        }

        static func < (first: Self, second: Self) -> Bool { first.rawValue < second.rawValue }
    }

    struct Bar: Equatable {
        let minY: CGFloat
        let height: CGFloat
        let widthFraction: CGFloat
        let ink: Ink
    }

    struct ChipTitle: Equatable {
        let text: String
        let width: CGFloat
    }

    struct Chip: Equatable {
        let letter: String
        let title: ChipTitle
        let rowY: CGFloat
        let chipY: CGFloat
    }

    private static let overflowRoundingOfAFittedPitchThatStillFits: CGFloat = 0.5

    let pitch: CGFloat
    let top: CGFloat
    let rowCount: Int
    let height: CGFloat
    let scrollOffset: CGFloat
    let maximumScrollOffset: CGFloat

    init(
        rowCount: Int, height: CGFloat, naturalPitch: CGFloat, verticalInset: CGFloat, minimumPitch: CGFloat = 0,
        offsetFromTop: CGFloat? = nil
    ) {
        self.rowCount = rowCount
        self.height = max(0, height)
        let available = max(0, height - 2 * verticalInset)
        let fitted = rowCount == 0 ? naturalPitch : min(naturalPitch, available / CGFloat(rowCount))
        pitch = max(fitted, min(minimumPitch, naturalPitch))
        let overflow = 2 * verticalInset + CGFloat(rowCount) * pitch - self.height
        maximumScrollOffset = overflow > Self.overflowRoundingOfAFittedPitchThatStillFits ? overflow : 0
        scrollOffset = min(max(0, offsetFromTop ?? maximumScrollOffset), maximumScrollOffset)
        top = verticalInset - scrollOffset
    }

    var isScrollable: Bool { maximumScrollOffset > 0 }

    func offsetFromTop(afterScrollingBy delta: CGFloat) -> CGFloat? {
        let offset = min(max(0, scrollOffset + delta), maximumScrollOffset)
        return offset >= maximumScrollOffset ? nil : offset
    }

    func scrollThumb(minimumLength: CGFloat) -> (minY: CGFloat, height: CGFloat)? {
        guard isScrollable else { return nil }
        let length = min(height, max(minimumLength, height * height / (height + maximumScrollOffset)))
        return ((height - length) * scrollOffset / maximumScrollOffset, length)
    }

    func y(ofRow row: Int) -> CGFloat { top + CGFloat(row) * pitch }

    private func blockIndicesInView(of outline: ConversationOutline) -> Range<Int> {
        guard pitch > 0, !outline.blocks.isEmpty else { return 0..<outline.blocks.count }
        let firstRow = max(0, Int(((0 - top) / pitch).rounded(.down)))
        let lastRow = Int(((height - top) / pitch).rounded(.up))
        var low = 0
        var high = outline.rowStarts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if outline.rowStarts[middle] <= firstRow { low = middle } else { high = middle - 1 }
        }
        var end = low
        while end < outline.blocks.count, outline.rowStarts[end] <= lastRow { end += 1 }
        return low..<max(low, end)
    }

    func row(atY y: CGFloat) -> Int {
        pitch > 0 ? min(max(0, Int((y - top) / pitch)), max(0, rowCount - 1)) : 0
    }

    func bars(for outline: ConversationOutline, pixel: CGFloat) -> [Bar] {
        var bars: [Bar] = []
        let columns = CGFloat(ConversationOutlineBuilder.columns)
        let blockIndices = blockIndicesInView(of: outline)
        if pitch >= 2 * pixel {
            let thickness = max(pixel, ((pitch * 2 / 3) / pixel).rounded() * pixel)
            for index in blockIndices {
                let block = outline.blocks[index]
                for (line, width) in block.lineWidths.enumerated() where width > 0 {
                    let minY = (y(ofRow: outline.rowStarts[index] + line) / pixel).rounded(.down) * pixel
                    bars.append(Bar(minY: minY, height: thickness, widthFraction: CGFloat(width) / columns, ink: Ink(block.kind)))
                }
            }
            return bars
        }
        var current: (pixelRow: Int, ink: Ink, width: CGFloat)?
        func flush() {
            if let current {
                bars.append(Bar(minY: CGFloat(current.pixelRow) * pixel, height: pixel, widthFraction: current.width, ink: current.ink))
            }
        }
        for index in blockIndices {
            let block = outline.blocks[index]
            let ink = Ink(block.kind)
            for (line, width) in block.lineWidths.enumerated() where width > 0 {
                let pixelRow = Int((y(ofRow: outline.rowStarts[index] + line) / pixel).rounded(.down))
                let fraction = CGFloat(width) / columns
                if let shared = current, shared.pixelRow == pixelRow {
                    current = (pixelRow, max(shared.ink, ink), max(shared.width, fraction))
                } else {
                    flush()
                    current = (pixelRow, ink, fraction)
                }
            }
        }
        flush()
        return bars
    }

    func chips(
        for bookmarks: [MessageBookmark], in outline: ConversationOutline, side: CGFloat, height: CGFloat,
        titles: [String: ChipTitle] = [:]
    ) -> [Chip] {
        var chips = bookmarks.compactMap { bookmark -> Chip? in
            guard let index = outline.blockIndex(for: bookmark) else { return nil }
            let rowY = y(ofRow: outline.rowStarts[index])
            let title = titles[bookmark.letter] ?? ChipTitle(text: bookmark.letter, width: side)
            return Chip(letter: bookmark.letter, title: title, rowY: rowY, chipY: rowY - side / 2)
        }.sorted { $0.rowY < $1.rowY }
        let step = chips.count > 1 ? min(side + 1, max(0, height - side) / CGFloat(chips.count - 1)) : side + 1
        var floor: CGFloat = 0
        for index in chips.indices {
            let chipY = max(chips[index].chipY, floor)
            chips[index] = Chip(letter: chips[index].letter, title: chips[index].title, rowY: chips[index].rowY, chipY: chipY)
            floor = chipY + step
        }
        var ceiling = height - side
        for index in chips.indices.reversed() {
            let chipY = max(0, min(chips[index].chipY, ceiling))
            chips[index] = Chip(letter: chips[index].letter, title: chips[index].title, rowY: chips[index].rowY, chipY: chipY)
            ceiling = chipY - step
        }
        return chips
    }

    func bookmark(at point: CGPoint, chips: [Chip], bookmarks: [MessageBookmark], width: CGFloat, side: CGFloat) -> MessageBookmark? {
        guard
            let chip = chips.last(where: {
                point.y >= $0.chipY && point.y <= $0.chipY + side && point.x >= Self.chipMinX(of: $0, width: width)
            })
        else { return nil }
        return bookmarks.first { $0.letter == chip.letter }
    }

    static func chipMinX(of chip: Chip, width: CGFloat) -> CGFloat {
        width - ConversationMapMetrics.chipGap - chip.title.width
    }
}
