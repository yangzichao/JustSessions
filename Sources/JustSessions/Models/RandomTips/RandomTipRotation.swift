struct RandomTipRotation: Equatable {
    private(set) var shownTips: Set<RandomTip>

    mutating func nextTip(after currentTip: RandomTip?, randomIndex: (Int) -> Int) -> RandomTip {
        var candidates = RandomTip.allCases.filter { !shownTips.contains($0) && $0 != currentTip }
        if candidates.isEmpty {
            shownTips = []
            candidates = RandomTip.allCases.filter { $0 != currentTip }
        }
        let nextTip = candidates[randomIndex(candidates.count)]
        shownTips.insert(nextTip)
        return nextTip
    }
}
