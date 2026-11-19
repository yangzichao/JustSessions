import SwiftUI

@MainActor
enum ThemeFont {
    static var title: Font { scaled(17, weight: .semibold) }
    static var heading: Font { scaled(13, weight: .semibold) }
    static var body: Font { scaled(13) }
    static var callout: Font { scaled(12) }
    static var fieldLabel: Font { scaled(11, weight: .medium) }
    static var detail: Font { scaled(11) }
    static var caption: Font { scaled(10) }

    static func glyph(_ size: ThemeGlyphSize, weight: Font.Weight = .regular) -> Font {
        scaled(size.rawValue, weight: weight)
    }

    static func scaled(_ size: CGFloat, weight: Font.Weight = .regular, in store: InterfaceSizeStore = .shared) -> Font {
        .system(size: size * InterfaceScale.factor(of: store), weight: weight)
    }
}
