/// SplitMix64. The same seed gives the same values, so a failing property test fails the same way on every run.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    mutating func string(of alphabet: [Character], lengthIn lengthRange: ClosedRange<Int>) -> String {
        let length = Int.random(in: lengthRange, using: &self)
        return String((0..<length).map { _ in alphabet.randomElement(using: &self)! })
    }
}
