import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// A SwiftUI sheet in a window on screen, which SwiftUI needs before it attaches the sheet.
@MainActor
@Suite(.serialized)
struct DismissesOnClickOutsideTests {
    @Test func aClickOnTheWindowAroundASwiftUISheetClosesIt() async throws {
        _ = NSApplication.shared
        let presentation = SheetPresentation()
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SheetPresentingView(presentation: presentation))
        window.center()
        window.orderFrontRegardless()
        defer { window.close() }

        presentation.isPresented = true
        try await expectEventually(timeout: .seconds(5)) { window.attachedSheet != nil }
        let click = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: CGPoint(x: 40, y: 40), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        NSApp.sendEvent(click)

        #expect(!presentation.isPresented)
        try await expectEventually(timeout: .seconds(5)) { window.attachedSheet == nil }
    }
}

@MainActor
private final class SheetPresentation: ObservableObject {
    @Published var isPresented = false
}

private struct SheetPresentingView: View {
    @ObservedObject var presentation: SheetPresentation

    var body: some View {
        Color.clear
            .sheet(isPresented: $presentation.isPresented) {
                Text("Sheet").frame(width: 200, height: 100)
            }
            .dismissesOnClickOutside(isPresented: $presentation.isPresented)
    }
}
