import SwiftUI

enum TabGroupPalette {
    static let colors: [ThemeColor] = (0..<8).map { ThemeColor(role: .tabGroup($0)) }

    static func colorsByProjectKey(_ projectKeys: [String]) -> [String: ThemeColor] {
        let colorIndices = TabGroupColorAssignment.colorIndices(forProjectKeys: projectKeys, paletteSize: colors.count)
        return Dictionary(uniqueKeysWithValues: zip(projectKeys, colorIndices.map { colors[$0] }))
    }
}
