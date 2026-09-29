import SwiftUI

/// A small green arc that turns while a CLI works. With Reduce Motion on it holds still; its open shape still sets
/// it apart from the dot of a CLI that is not working.
struct WorkingSpinner: View {
    static let secondsPerTurn = 0.9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            arc(turnedBy: .zero)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let turns = context.date.timeIntervalSinceReferenceDate / Self.secondsPerTurn
                arc(turnedBy: .degrees(turns.truncatingRemainder(dividingBy: 1) * 360))
            }
        }
    }

    private func arc(turnedBy angle: Angle) -> some View {
        Circle()
            .trim(from: 0, to: 0.72)
            .stroke(ThemePalette.live, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .rotationEffect(angle)
            .frame(width: 8, height: 8)
    }
}
