import SwiftUI

@MainActor
enum ThemeFont {
    enum DefaultPointSize {
        static let title: CGFloat = 17
        static let heading: CGFloat = 13
        static let body: CGFloat = 13
        static let callout: CGFloat = 12
        static let fieldLabel: CGFloat = 11
        static let detail: CGFloat = 11
        static let caption: CGFloat = 10
    }

    static var title: Font { scaled(DefaultPointSize.title, weight: .semibold) }
    static var heading: Font { scaled(DefaultPointSize.heading, weight: .semibold) }
    static var body: Font { scaled(DefaultPointSize.body) }
    static var callout: Font { scaled(DefaultPointSize.callout) }
    static var fieldLabel: Font { scaled(DefaultPointSize.fieldLabel, weight: .medium) }
    static var detail: Font { scaled(DefaultPointSize.detail) }
    static var caption: Font { scaled(DefaultPointSize.caption) }

    static func glyph(_ size: ThemeGlyphSize, weight: Font.Weight = .regular) -> Font {
        scaled(size.rawValue, weight: weight)
    }

    static func scaled(_ size: CGFloat, weight: Font.Weight = .regular, in store: InterfaceSizeStore = .shared) -> Font {
        .system(size: size * InterfaceScale.factor(of: store), weight: weight)
    }
}
