import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// The sidebar's resize handle lies over the detail's leading edge, not in a strip of its own beside it.
@MainActor
struct SidebarResizeHandleTests {
    /// The sidebar's width with no width saved, so the divider's place is known.
    private let sidebarWidth: CGFloat = 248
    private let windowSize = CGSize(width: 1000, height: 600)

    @Test func detailShowsThroughTheHandle() async throws {
        let fixture = try ResizableSidebarLayoutFixture(size: windowSize, detail: VStack(spacing: 0) {
            Color.blue.frame(height: 40)
            Color.green
        })
        defer { fixture.close() }
        let bitmap = try await fixture.capture()
        let renderingScale = CGFloat(bitmap.pixelsWide) / windowSize.width
        // One row through the top band, where the tab bar sits, and one through the rest, where the terminal does.
        for row in [CGFloat(20), 300] {
            let pixelY = Int(row * renderingScale)
            let underHandle = try #require(bitmap.colorAt(x: Int((sidebarWidth + 5) * renderingScale), y: pixelY))
            let insideDetail = try #require(bitmap.colorAt(x: Int((sidebarWidth + 100) * renderingScale), y: pixelY))
            #expect(hexValue(of: underHandle) == hexValue(of: insideDetail), "row \(row)")
        }
    }

    /// The terminal is an AppKit view, which would take every click over it from a handle drawn underneath.
    @Test func handleTakesTheMouseOverAnAppKitDetail() async throws {
        let fixture = try ResizableSidebarLayoutFixture(size: windowSize, detail: AppKitDetail())
        defer { fixture.close() }
        try await fixture.settle()

        let viewUnderHandle = fixture.hitView(at: CGPoint(x: sidebarWidth + 5, y: 300))
        #expect(viewUnderHandle != nil)
        #expect(!(viewUnderHandle is AppKitDetailView))
        #expect(fixture.hitView(at: CGPoint(x: sidebarWidth + 20, y: 300)) is AppKitDetailView)
    }

    private func hexValue(of color: NSColor) -> UInt32 {
        [color.redComponent, color.greenComponent, color.blueComponent].reduce(0) { result, component in
            result << 8 | UInt32((component * 255).rounded())
        }
    }
}

@MainActor
private final class ResizableSidebarLayoutFixture {
    private let settings: IsolatedUserDefaults
    private let hostingView: NSHostingView<AnyView>
    private let window: NSWindow

    init(size: CGSize, detail: some View) throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        hostingView = NSHostingView(rootView: AnyView(
            ResizableSidebarLayout(isSidebarHidden: false) { Color.red } detail: { detail }
                .defaultAppStorage(settings.userDefaults)
        ))
        window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    func settle() async throws {
        for _ in 0..<4 {
            hostingView.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    func capture() async throws -> NSBitmapImageRep {
        try await settle()
        let bitmap = try #require(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return bitmap
    }

    /// The view a click at `point`, from the window's top-leading corner, would go to.
    func hitView(at point: CGPoint) -> NSView? {
        hostingView.hitTest(hostingView.convert(point, to: hostingView.superview))
    }

    func close() {
        hostingView.rootView = AnyView(EmptyView())
        window.close()
        settings.removeSuite()
    }
}

private final class AppKitDetailView: NSView {}

private struct AppKitDetail: NSViewRepresentable {
    func makeNSView(context: Context) -> AppKitDetailView { AppKitDetailView() }
    func updateNSView(_ nsView: AppKitDetailView, context: Context) {}
}
