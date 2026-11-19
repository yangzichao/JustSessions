import AppKit

struct DrawnTextLines {
    private let contrast: [[Double]]
    let lines: [Range<Int>]

    init(_ bitmap: NSBitmapImageRep) {
        var grays: [[Double]] = []
        var grayCounts: [Int: Int] = [:]
        for y in 0..<bitmap.pixelsHigh {
            let row = (0..<bitmap.pixelsWide).map { x in
                Double(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceGray)?.whiteComponent ?? 0)
            }
            for gray in row { grayCounts[Int(gray * 255), default: 0] += 1 }
            grays.append(row)
        }
        let background = Double(grayCounts.max { $0.value < $1.value }?.key ?? 0) / 255
        contrast = grays.map { row in row.map { abs($0 - background) } }
        var lines: [Range<Int>] = []
        var start: Int?
        for (y, row) in contrast.enumerated() {
            let hasText = (row.max() ?? 0) > 0.3
            if hasText, start == nil { start = y }
            if !hasText, let lineStart = start {
                lines.append(lineStart..<y)
                start = nil
            }
        }
        self.lines = lines
    }

    func ink(ofLine index: Int) -> Double {
        lines[index].reduce(0) { sum, y in sum + contrast[y].filter { $0 > 0.1 }.reduce(0, +) }
    }

    func height(ofLine index: Int) -> Int {
        lines[index].count
    }
}
