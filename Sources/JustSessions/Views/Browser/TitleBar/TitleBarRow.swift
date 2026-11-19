import SwiftUI

struct TitleBarRow: Equatable {
    var height: CGFloat
    var controlsTrailingEdge: CGFloat
}

extension EnvironmentValues {
    @Entry var titleBarRow = TitleBarRow(height: 28, controlsTrailingEdge: 162)
}
