enum TerminalColorIntensity {
    static let percentRange = 50...200
    static let defaultPercent = 100
    static let percentStep = 5

    static func adjusted(_ hexValue: UInt32, percent: Int) -> UInt32 {
        guard percent != defaultPercent else { return hexValue }
        let color = OKLabColor(hexValue: hexValue)
        let targetChroma = color.chroma * Double(percent) / 100
        let target = color.withChroma(targetChroma)
        if target.isInSRGB { return target.hexValue }
        var shownChroma = color.chroma
        var unshownChroma = targetChroma
        for _ in 0..<24 {
            let middleChroma = (shownChroma + unshownChroma) / 2
            if color.withChroma(middleChroma).isInSRGB { shownChroma = middleChroma } else { unshownChroma = middleChroma }
        }
        return color.withChroma(shownChroma).hexValue
    }
}
