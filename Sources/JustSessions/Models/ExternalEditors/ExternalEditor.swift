import Foundation

/// A code editor or IDE that "Open project in" offers when it is installed on this Mac. An editor published under
/// several bundle identifiers lists them newest first; the first one found is used. An editor with an SSH remote mode
/// also opens projects on SSH hosts; see `RemoteProjectOpening`.
struct ExternalEditor: Hashable, Sendable {
    let name: String
    let bundleIdentifiers: [String]
    let remoteProjectOpening: RemoteProjectOpening?

    init(name: String, bundleIdentifiers: [String], remoteProjectOpening: RemoteProjectOpening? = nil) {
        self.name = name
        self.bundleIdentifiers = bundleIdentifiers
        self.remoteProjectOpening = remoteProjectOpening
    }
}

extension ExternalEditor {
    /// Every editor the menu knows, in menu order. The bundle identifiers match GitHub Desktop's editor list
    /// (`app/src/lib/editors/darwin.ts`), plus Antigravity and Antigravity IDE. JetBrains IDEs open SSH projects when
    /// JetBrains supports remote development for them, which leaves out the Community editions, DataSpell, RustRover,
    /// and Android Studio.
    static let knownEditors: [ExternalEditor] = [
        ExternalEditor(name: "Android Studio", bundleIdentifiers: ["com.google.android.studio"]),
        // Antigravity 2's app, which runs agents. Antigravity IDE is the editor.
        ExternalEditor(name: "Antigravity", bundleIdentifiers: ["com.google.antigravity"]),
        ExternalEditor(
            name: "Antigravity IDE",
            bundleIdentifiers: ["com.google.antigravity-ide"],
            remoteProjectOpening: .vscodeRemoteSSH(urlScheme: "antigravity-ide")
        ),
        ExternalEditor(
            name: "CLion",
            bundleIdentifiers: ["com.jetbrains.CLion"],
            remoteProjectOpening: .jetBrainsToolbox(productCode: "CL")
        ),
        ExternalEditor(
            name: "Cursor",
            bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"],
            remoteProjectOpening: .vscodeRemoteSSH(urlScheme: "cursor")
        ),
        ExternalEditor(name: "DataSpell", bundleIdentifiers: ["com.jetbrains.DataSpell"]),
        ExternalEditor(
            name: "GoLand",
            bundleIdentifiers: ["com.jetbrains.goland"],
            remoteProjectOpening: .jetBrainsToolbox(productCode: "GO")
        ),
        ExternalEditor(
            name: "IntelliJ IDEA",
            bundleIdentifiers: ["com.jetbrains.intellij"],
            remoteProjectOpening: .jetBrainsToolbox(productCode: "IU")
        ),
        ExternalEditor(name: "IntelliJ IDEA CE", bundleIdentifiers: ["com.jetbrains.intellij.ce"]),
        ExternalEditor(name: "Nova", bundleIdentifiers: ["com.panic.Nova"]),
        ExternalEditor(
            name: "PhpStorm",
            bundleIdentifiers: ["com.jetbrains.PhpStorm"],
            remoteProjectOpening: .jetBrainsToolbox(productCode: "PS")
        ),
        ExternalEditor(
            name: "PyCharm",
            bundleIdentifiers: ["com.jetbrains.PyCharm"],
            remoteProjectOpening: .jetBrainsToolbox(productCode: "PY")
        ),
        ExternalEditor(name: "PyCharm CE", bundleIdentifiers: ["com.jetbrains.pycharm.ce"]),
        ExternalEditor(
            name: "Rider",
            bundleIdentifiers: ["com.jetbrains.rider"],
            remoteProjectOpening: .jetBrainsToolbox(productCode: "RD")
        ),
        ExternalEditor(
            name: "RubyMine",
            bundleIdentifiers: ["com.jetbrains.RubyMine"],
            remoteProjectOpening: .jetBrainsToolbox(productCode: "RM")
        ),
        ExternalEditor(name: "RustRover", bundleIdentifiers: ["com.jetbrains.RustRover"]),
        ExternalEditor(
            name: "Sublime Text",
            bundleIdentifiers: ["com.sublimetext.4", "com.sublimetext.3", "com.sublimetext.2"]
        ),
        ExternalEditor(
            name: "Visual Studio Code",
            bundleIdentifiers: ["com.microsoft.VSCode"],
            remoteProjectOpening: .vscodeRemoteSSH(urlScheme: "vscode")
        ),
        ExternalEditor(
            name: "Visual Studio Code Insiders",
            bundleIdentifiers: ["com.microsoft.VSCodeInsiders"],
            remoteProjectOpening: .vscodeRemoteSSH(urlScheme: "vscode-insiders")
        ),
        ExternalEditor(
            name: "VSCodium",
            bundleIdentifiers: ["com.vscodium", "com.visualstudio.code.oss"],
            remoteProjectOpening: .vscodeRemoteSSH(urlScheme: "vscodium")
        ),
        ExternalEditor(
            name: "WebStorm",
            bundleIdentifiers: ["com.jetbrains.WebStorm"],
            remoteProjectOpening: .jetBrainsToolbox(productCode: "WS")
        ),
        ExternalEditor(
            name: "Windsurf",
            bundleIdentifiers: ["com.exafunction.windsurf"],
            remoteProjectOpening: .vscodeRemoteSSH(urlScheme: "windsurf")
        ),
        ExternalEditor(name: "Xcode", bundleIdentifiers: ["com.apple.dt.Xcode"]),
        ExternalEditor(name: "Zed", bundleIdentifiers: ["dev.zed.Zed"], remoteProjectOpening: .zed),
        ExternalEditor(name: "Zed Preview", bundleIdentifiers: ["dev.zed.Zed-Preview"], remoteProjectOpening: .zed),
    ]
}
