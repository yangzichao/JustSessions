import SwiftUI

enum ThemeShadow {
    case floating
    case raisedSegment

    fileprivate var color: Color {
        switch self {
        case .floating: .black.opacity(0.18)
        case .raisedSegment: .black.opacity(0.12)
        }
    }

    fileprivate var radius: CGFloat {
        switch self {
        case .floating: 6
        case .raisedSegment: 0.5
        }
    }

    fileprivate var yOffset: CGFloat {
        switch self {
        case .floating: 2
        case .raisedSegment: 0.5
        }
    }
}

extension View {
    func themeShadow(_ shadow: ThemeShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, y: shadow.yOffset)
    }
}
