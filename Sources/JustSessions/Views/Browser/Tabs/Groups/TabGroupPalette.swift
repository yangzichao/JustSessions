import SwiftUI

/// Stable project color roles. Their hues resolve from the view's chosen theme and appearance at render time.
enum TabGroupPalette {
    static let colors: [ThemeColor] = (0..<8).map { ThemeColor(role: .tabGroup($0)) }

    /// Each group's color, by project key.
    static func colorsByProjectKey(_ projectKeys: [String]) -> [String: ThemeColor] {
        let colorIndices = TabGroupColorAssignment.colorIndices(forProjectKeys: projectKeys, paletteSize: colors.count)
        return Dictionary(uniqueKeysWithValues: zip(projectKeys, colorIndices.map { colors[$0] }))
    }
}
