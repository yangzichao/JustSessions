struct AdaptiveHexColor: Equatable, Sendable {
    let light: UInt32
    let dark: UInt32

    func value(isDark: Bool) -> UInt32 {
        isDark ? dark : light
    }
}
