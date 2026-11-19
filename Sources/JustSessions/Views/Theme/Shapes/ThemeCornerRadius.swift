import SwiftUI

enum ThemeCornerRadius: CGFloat {
    case checkbox = 3
    case small = 4
    case control = 6
    case card = 8
    case panel = 10
}

extension RoundedRectangle {
    init(_ radius: ThemeCornerRadius) {
        self.init(cornerRadius: radius.rawValue, style: .continuous)
    }
}
