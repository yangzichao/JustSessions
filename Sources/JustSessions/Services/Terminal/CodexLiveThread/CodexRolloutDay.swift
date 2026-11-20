import Foundation

struct CodexRolloutDay: Comparable {
    let year: Int
    let month: Int
    let day: Int

    static let beforeEveryRollout = CodexRolloutDay(year: 0, month: 0, day: 0)

    static func < (earlier: CodexRolloutDay, later: CodexRolloutDay) -> Bool {
        (earlier.year, earlier.month, earlier.day) < (later.year, later.month, later.day)
    }
}

extension CodexRolloutDay {
    init(of date: Date, in calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }
}
