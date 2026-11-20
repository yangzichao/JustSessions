import SwiftUI

@MainActor
final class SidebarRowFrames {
    nonisolated static let coordinateSpace = "sidebarProjectList"

    private struct ReportedFrame {
        let projectPath: String
        let frame: CGRect
    }

    private var reportedFrames: [SidebarRowID: ReportedFrame] = [:]

    func report(_ frame: CGRect?, ofRow rowID: SidebarRowID, inProject projectPath: String) {
        reportedFrames[rowID] = frame.map { ReportedFrame(projectPath: projectPath, frame: $0) }
    }

    var framesByRowID: [SidebarRowID: CGRect] {
        reportedFrames.mapValues(\.frame)
    }

    func bottom(ofProject projectPath: String) -> CGFloat? {
        reportedFrames.values.filter { $0.projectPath == projectPath }.map(\.frame.maxY).max()
    }
}

extension View {
    func reportsSidebarRowFrame(_ rowID: SidebarRowID, inProject projectPath: String, to rowFrames: SidebarRowFrames) -> some View {
        onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(SidebarRowFrames.coordinateSpace))
        } action: { frame in
            rowFrames.report(frame, ofRow: rowID, inProject: projectPath)
        }
        .onDisappear { rowFrames.report(nil, ofRow: rowID, inProject: projectPath) }
    }

    func sidebarRowFramesCoordinateSpace() -> some View {
        coordinateSpace(.named(SidebarRowFrames.coordinateSpace))
    }
}
