import SwiftUI

/// Where the project list's rows in sight lay out, for a drag among the pinned ones to work out where it would land.
/// A reference the rows write to as they lay out, rather than state, so laying out or scrolling redraws nothing.
@MainActor
final class SidebarRowFrames {
    /// The project list's coordinate space, which scrolls with its rows, so their frames hold while it scrolls.
    nonisolated static let coordinateSpace = "sidebarProjectList"

    private struct ReportedFrame {
        let projectPath: String
        let frame: CGRect
    }

    /// By row id; a row leaves once it is out of sight.
    private var reportedFrames: [String: ReportedFrame] = [:]

    func report(_ frame: CGRect?, ofRow rowID: String, inProject projectPath: String) {
        reportedFrames[rowID] = frame.map { ReportedFrame(projectPath: projectPath, frame: $0) }
    }

    var framesByRowID: [String: CGRect] {
        reportedFrames.mapValues(\.frame)
    }

    /// The bottom of the lowest of the project's rows in sight: its own row's, or that of its last session or the
    /// subagents' sessions under it.
    func bottom(ofProject projectPath: String) -> CGFloat? {
        reportedFrames.values.filter { $0.projectPath == projectPath }.map(\.frame.maxY).max()
    }
}

extension View {
    /// Reports where the row, one of `projectPath`'s or that project's own, lays out in the project list to
    /// `rowFrames`, until it goes out of sight.
    func reportsSidebarRowFrame(_ rowID: String, inProject projectPath: String, to rowFrames: SidebarRowFrames) -> some View {
        onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(SidebarRowFrames.coordinateSpace))
        } action: { frame in
            rowFrames.report(frame, ofRow: rowID, inProject: projectPath)
        }
        .onDisappear { rowFrames.report(nil, ofRow: rowID, inProject: projectPath) }
    }

    /// The coordinate space the rows report their frames in and drags follow the pointer in.
    func sidebarRowFramesCoordinateSpace() -> some View {
        coordinateSpace(.named(SidebarRowFrames.coordinateSpace))
    }
}
