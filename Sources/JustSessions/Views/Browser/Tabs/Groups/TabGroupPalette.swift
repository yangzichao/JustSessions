import SwiftUI

/// Tab group colors, after a browser's tab group colors: a deep shade that stays readable as text on the tab bar in
/// light mode, and a light one in dark mode.
enum TabGroupPalette {
    static let colors: [Color] = [
        .adaptive(light: 0x1A73E8, dark: 0x8AB4F8), // blue
        .adaptive(light: 0xC5221F, dark: 0xF28B82), // red
        .adaptive(light: 0x9E5A00, dark: 0xFDD663), // amber
        .adaptive(light: 0x188038, dark: 0x81C995), // green
        .adaptive(light: 0xC2185B, dark: 0xFF8BCB), // pink
        .adaptive(light: 0x8430CE, dark: 0xC58AF9), // purple
        .adaptive(light: 0x007B83, dark: 0x78D9EC), // cyan
        .adaptive(light: 0xC25400, dark: 0xFCAD70), // orange
    ]

    /// Each group's color, by project key.
    static func colorsByProjectKey(_ projectKeys: [String]) -> [String: Color] {
        let colorIndices = TabGroupColorAssignment.colorIndices(forProjectKeys: projectKeys, paletteSize: colors.count)
        return Dictionary(uniqueKeysWithValues: zip(projectKeys, colorIndices.map { colors[$0] }))
    }
}
