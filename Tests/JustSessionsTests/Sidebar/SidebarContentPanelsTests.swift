import AppKit
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
struct SidebarContentPanelsTests {
    @Test func switchingListsPreservesBothNativeScrollPositions() async throws {
        _ = NSApplication.shared
        let selection = Selection()
        let hostingView = NSHostingView(rootView: Lists(selection: selection))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 300),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        defer { window.close() }
        try await settle(hostingView)

        let originalScrollViews = scrollViews(in: hostingView)
        #expect(originalScrollViews.count == 2)
        guard originalScrollViews.count == 2 else { return }
        for (index, scrollView) in originalScrollViews.enumerated() {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: CGFloat(160 + index * 120)))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        let originalOffsets = originalScrollViews.map { $0.contentView.bounds.origin.y }
        #expect(originalOffsets.allSatisfy { $0 > 0 })

        for mode in [SidebarContentMode.openTabs, .projects, .openTabs] {
            selection.mode = mode
            try await settle(hostingView)
            let currentScrollViews = scrollViews(in: hostingView)
            #expect(currentScrollViews.map(ObjectIdentifier.init) == originalScrollViews.map(ObjectIdentifier.init))
            #expect(currentScrollViews.map { $0.contentView.bounds.origin.y } == originalOffsets)
        }
    }

    private func settle(_ view: NSView) async throws {
        for _ in 0..<4 {
            view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private final class Selection: ObservableObject {
        @Published var mode: SidebarContentMode = .projects
    }

    private struct Lists: View {
        @ObservedObject var selection: Selection

        var body: some View {
            SidebarContentPanels(selection: selection.mode) {
                list(prefix: "Project")
            } openTabs: {
                list(prefix: "Tab")
            }
        }

        private func list(prefix: String) -> some View {
            ScrollView {
                VStack {
                    ForEach(0..<80) { index in
                        Text(verbatim: "\(prefix) \(index)").frame(height: 32)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
