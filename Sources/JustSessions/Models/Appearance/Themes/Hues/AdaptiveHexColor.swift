/// A color as 0xRRGGBB values, one for the light appearance and one for the dark.
struct AdaptiveHexColor: Equatable, Sendable {
    let light: UInt32
    let dark: UInt32

    func value(isDark: Bool) -> UInt32 {
        isDark ? dark : light
    }
}
