import SwiftUI

/// The terminal font: the system's monospaced font, or any monospaced family installed on this Mac whose letters fill a
/// terminal's cells. A chosen family that is no longer installed, or whose letters don't fill the cells, stays listed,
/// marked, while terminals use the system's font.
struct TerminalFontPicker: View {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    /// Nil until the installed families have loaded.
    @State private var installedFamilies: InstalledMonospacedFontFamilies?

    var body: some View {
        HStack(spacing: 4) {
            picker
            // macOS gives its system fonts no fallback fonts; see TerminalFontFamily.
            HelpPopoverButton(
                title: "Nerd Font icons",
                explanation:
                    "System Monospaced can't show the included Nerd Font icons. To see them, as in shell prompts, choose another font, such as Menlo."
            )
            .accessibilityIdentifier("settings.help.terminalFont")
        }
    }

    private var picker: some View {
        Picker(
            "Font",
            selection: Binding(
                get: { appearanceStore.preferences.fontFamily },
                set: { appearanceStore.setFontFamily($0) }
            )
        ) {
            Text("System Monospaced").tag(TerminalFontFamily.system)
            Divider()
            ForEach(Self.choices(installed: installedFamilies, chosen: appearanceStore.preferences.fontFamily), id: \.self) { choice in
                switch choice.unavailability {
                case .notInstalled:
                    Text("\(choice.family) (not installed)").tag(TerminalFontFamily.named(choice.family))
                case .notFillingCells:
                    Text("\(choice.family) (not supported)").tag(TerminalFontFamily.named(choice.family))
                case nil:
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
        /// Why terminals use the system's font instead, known only once the installed families have loaded.
        let unavailability: Unavailability?
    }

    enum Unavailability: Hashable {
        case notInstalled
        /// See `FontFillsTerminalCells`.
        case notFillingCells
    }

    /// The families whose letters fill the cells, and the chosen one even before they load, after it is removed, or
    /// when its letters don't, so the picker always shows the current choice.
    static func choices(installed: InstalledMonospacedFontFamilies?, chosen: TerminalFontFamily) -> [Choice] {
        var families = installed?.fillingCells ?? []
        if case .named(let chosenFamily) = chosen, !families.contains(chosenFamily) {
            families.append(chosenFamily)
            families.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        }
        return families.map { family in
            Choice(family: family, unavailability: installed.flatMap { unavailability(of: family, in: $0) })
        }
    }

    private static func unavailability(of family: String, in installed: InstalledMonospacedFontFamilies) -> Unavailability? {
        if installed.fillingCells.contains(family) { return nil }
        return installed.notFillingCells.contains(family) ? .notFillingCells : .notInstalled
    }
}
