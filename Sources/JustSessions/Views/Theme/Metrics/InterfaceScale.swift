import SwiftUI

@MainActor
enum InterfaceScale {
    static var factor: CGFloat { factor(of: .shared) }

    static func factor(of store: InterfaceSizeStore) -> CGFloat {
        CGFloat(store.scale)
    }

    static func points(_ points: CGFloat) -> CGFloat {
        self.points(points, at: factor)
    }

    static func points(_ points: CGFloat, at factor: CGFloat) -> CGFloat {
        (points * factor * 2).rounded() / 2
    }

    static var controlSize: ControlSize { controlSize(at: factor) }

    static func controlSize(at factor: CGFloat) -> ControlSize {
        switch factor {
        case ..<0.95: .small
        case ..<1.15: .regular
        case ..<1.35: .large
        default: .extraLarge
        }
    }
}
