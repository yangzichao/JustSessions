import Foundation

/// Picks each tab group's color from a palette. A project keeps the color its key hashes to, across launches, unless
/// a group before it already took that color; then it takes the next free one, so open groups differ while the
/// palette has colors to go around.
enum TabGroupColorAssignment {
    /// Palette indices, one per project key, in the given order.
    static func colorIndices(forProjectKeys projectKeys: [String], paletteSize: Int) -> [Int] {
        guard paletteSize > 0 else { return projectKeys.map { _ in 0 } }
        var takenColorIndices: Set<Int> = []
        return projectKeys.map { projectKey in
            let preferredColorIndex = preferredColorIndex(forProjectKey: projectKey, paletteSize: paletteSize)
            let colorIndex = (0..<paletteSize)
                .map { (preferredColorIndex + $0) % paletteSize }
                .first { !takenColorIndices.contains($0) } ?? preferredColorIndex
            takenColorIndices.insert(colorIndex)
            return colorIndex
        }
    }

    /// From a 64-bit FNV-1a hash of the key, which, unlike `hashValue`, stays the same from one launch to the next.
    static func preferredColorIndex(forProjectKey projectKey: String, paletteSize: Int) -> Int {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in projectKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return Int(hash % UInt64(paletteSize))
    }
}
