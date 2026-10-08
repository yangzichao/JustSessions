import AppKit
import CoreText

/// Draws Nerd Font icons, such as the Powerline separators and file icons of shell prompts and TUIs, whatever font the
/// terminal uses. The app bundles Symbols Nerd Font Mono, which has only icons, each one cell wide. It joins the terminal
/// font's fallback list for the Private Use Areas, where Nerd Fonts put their icons, so characters the terminal font has
/// keep its glyphs, and other characters it lacks keep the system's usual fallback. macOS ignores fallback fonts for its
/// own system fonts, so System Monospaced shows only the icons macOS's fallback finds.
enum TerminalSymbolsFont {
    static let postScriptName = "SymbolsNFM"
    /// The symbols-only families, which the font picker leaves out: they have icons but no letters.
    static let familyNames: Set<String> = ["Symbols Nerd Font Mono", "Symbols Nerd Font"]

    /// The font, falling back to the symbols font for icons. SwiftTerm derives its bold and italic fonts from it, and
    /// they keep the fallback.
    static func addingFallback(to font: NSFont) -> NSFont {
        guard register() else { return font }
        let symbols = NSFontDescriptor(fontAttributes: [.name: postScriptName, .characterSet: privateUseAreas])
        let descriptor = font.fontDescriptor.addingAttributes([.cascadeList: [symbols]])
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    /// Registers the bundled font for this process, once, and returns whether the symbols font is available. A copy
    /// installed on the Mac has the same name and draws the same icons, so either one serves.
    @discardableResult
    static func register() -> Bool { isAvailable }

    private static let isAvailable: Bool = {
        if let url = AppLocalization.resourceBundle.url(forResource: "SymbolsNerdFontMono-Regular", withExtension: "ttf", subdirectory: "Fonts") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return NSFont(name: postScriptName, size: NSFont.systemFontSize) != nil
    }()

    private static let privateUseAreas: CharacterSet = {
        var characters = CharacterSet(charactersIn: "\u{E000}"..."\u{F8FF}")
        characters.insert(charactersIn: "\u{F0000}"..."\u{FFFFD}")
        characters.insert(charactersIn: "\u{100000}"..."\u{10FFFD}")
        return characters
    }()
}
