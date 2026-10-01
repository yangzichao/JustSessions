import Foundation

/// A code editor or IDE that "Open project in" offers when it is installed on this Mac. An editor published under
/// several bundle identifiers lists them newest first; the first one found is used.
struct ExternalEditor: Hashable, Sendable {
    let name: String
    let bundleIdentifiers: [String]
}

extension ExternalEditor {
    /// Every editor the menu knows, in menu order. The bundle identifiers match GitHub Desktop's editor list
    /// (`app/src/lib/editors/darwin.ts`), plus Antigravity.
    static let knownEditors: [ExternalEditor] = [
        ExternalEditor(name: "Android Studio", bundleIdentifiers: ["com.google.android.studio"]),
        ExternalEditor(name: "Antigravity", bundleIdentifiers: ["com.google.antigravity"]),
        ExternalEditor(name: "CLion", bundleIdentifiers: ["com.jetbrains.CLion"]),
        ExternalEditor(name: "Cursor", bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"]),
        ExternalEditor(name: "DataSpell", bundleIdentifiers: ["com.jetbrains.DataSpell"]),
        ExternalEditor(name: "GoLand", bundleIdentifiers: ["com.jetbrains.goland"]),
        ExternalEditor(name: "IntelliJ IDEA", bundleIdentifiers: ["com.jetbrains.intellij"]),
        ExternalEditor(name: "IntelliJ IDEA CE", bundleIdentifiers: ["com.jetbrains.intellij.ce"]),
        ExternalEditor(name: "Nova", bundleIdentifiers: ["com.panic.Nova"]),
        ExternalEditor(name: "PhpStorm", bundleIdentifiers: ["com.jetbrains.PhpStorm"]),
        ExternalEditor(name: "PyCharm", bundleIdentifiers: ["com.jetbrains.PyCharm"]),
        ExternalEditor(name: "PyCharm CE", bundleIdentifiers: ["com.jetbrains.pycharm.ce"]),
        ExternalEditor(name: "Rider", bundleIdentifiers: ["com.jetbrains.rider"]),
        ExternalEditor(name: "RubyMine", bundleIdentifiers: ["com.jetbrains.RubyMine"]),
        ExternalEditor(name: "RustRover", bundleIdentifiers: ["com.jetbrains.RustRover"]),
        ExternalEditor(
            name: "Sublime Text",
            bundleIdentifiers: ["com.sublimetext.4", "com.sublimetext.3", "com.sublimetext.2"]
        ),
        ExternalEditor(name: "Visual Studio Code", bundleIdentifiers: ["com.microsoft.VSCode"]),
        ExternalEditor(name: "Visual Studio Code Insiders", bundleIdentifiers: ["com.microsoft.VSCodeInsiders"]),
        ExternalEditor(name: "VSCodium", bundleIdentifiers: ["com.vscodium", "com.visualstudio.code.oss"]),
        ExternalEditor(name: "WebStorm", bundleIdentifiers: ["com.jetbrains.WebStorm"]),
        ExternalEditor(name: "Windsurf", bundleIdentifiers: ["com.exafunction.windsurf"]),
        ExternalEditor(name: "Xcode", bundleIdentifiers: ["com.apple.dt.Xcode"]),
        ExternalEditor(name: "Zed", bundleIdentifiers: ["dev.zed.Zed"]),
        ExternalEditor(name: "Zed Preview", bundleIdentifiers: ["dev.zed.Zed-Preview"]),
    ]
}
