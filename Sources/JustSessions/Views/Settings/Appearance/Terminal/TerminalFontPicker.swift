import SwiftUI

/// The terminal font: the system's monospaced font, or any monospaced family installed on this Mac. A chosen family
/// that is no longer installed stays listed, marked, while terminals use the system's font.
struct TerminalFontPicker: View {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    /// Nil until the installed families have loaded.
    @State private var installedFamilies: [String]?

    var body: some View {
        HStack(spacing: 4) {
            picker
            // macOS gives its system fonts no fallback fonts; see TerminalFontFamily.
            HelpPopoverButton(
                title: "Nerd Font icons",
                explanation: "System Monospaced can't show the included Nerd Font icons. To see them, as in shell prompts, choose another font, such as Menlo."
            )
            .accessibilityIdentifier("settings.help.terminalFont")
        }
    }

    private var picker: some View {
        Picker("Font", selection: Binding(
            get: { appearanceStore.preferences.fontFamily },
            set: { appearanceStore.setFontFamily($0) }
        )) {
            Text("System Monospaced").tag(TerminalFontFamily.system)
            Divider()
            ForEach(Self.choices(installed: installedFamilies, chosen: appearanceStore.preferences.fontFamily), id: \.self) { choice in
                if choice.isMissing {
                    Text("\(choice.family) (not installed)").tag(TerminalFontFamily.named(choice.family))
                } else {
                    Text(verbatim: choice.family).tag(TerminalFontFamily.named(choice.family))
                }
            }
        }
        .labelsHidden()
        .help("Lists the monospaced fonts installed on this Mac.")
        .task {
            installedFamilies = await Task.detached(priority: .userInitiated) { InstalledMonospacedFontFamilies.load() }.value
        }
    }

    struct Choice: Hashable {
        let family: String
        /// Known only once the installed families have loaded.
        let isMissing: Bool
    }

    /// The installed families, and the chosen one even before they load or after it is removed, so the picker always
    /// shows the current choice.
    static func choices(installed: [String]?, chosen: TerminalFontFamily) -> [Choice] {
        var families = installed ?? []
        if case .named(let chosenFamily) = chosen, !families.contains(chosenFamily) {
            families.append(chosenFamily)
            families.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        }
        return families.map { family in
            Choice(family: family, isMissing: installed.map { !$0.contains(family) } ?? false)
        }
    }
}
