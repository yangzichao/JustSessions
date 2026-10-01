import AppKit
import SwiftUI
import Testing

@MainActor
final class ThemeSurfaceRenderingFixture {
    private let hostingView: NSHostingView<AnyView>
    private let window: NSWindow

    init(content: AnyView, size: CGSize, colorScheme: ColorScheme) {
        _ = NSApplication.shared
        hostingView = NSHostingView(rootView: AnyView(content.environment(\.colorScheme, colorScheme)))
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.contentView = hostingView
    }

    func capture(named name: String) async throws -> NSBitmapImageRep {
        for _ in 0..<4 {
            hostingView.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
        let bitmap = try #require(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        if let directory = ProcessInfo.processInfo.environment["JUSTSESSIONS_THEME_SCREENSHOTS"] {
            let outputDirectory = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let imageData = try #require(bitmap.representation(using: .png, properties: [:]))
            try imageData.write(to: outputDirectory.appendingPathComponent(name + ".png"))
        }
        return bitmap
    }

    func close() {
        hostingView.rootView = AnyView(EmptyView())
        window.close()
    }
}
