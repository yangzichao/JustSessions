enum TextZoomStep {
    case zoomIn
    case zoomOut
    case actualSize

    func size(after size: Double, in range: ClosedRange<Double>, defaultSize: Double) -> Double {
        switch self {
        case .zoomIn: min(max(size + 1, range.lowerBound), range.upperBound)
        case .zoomOut: min(max(size - 1, range.lowerBound), range.upperBound)
        case .actualSize: defaultSize
        }
    }
}
