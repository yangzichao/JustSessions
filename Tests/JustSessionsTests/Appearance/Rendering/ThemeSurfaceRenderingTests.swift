import AppKit
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
struct ThemeSurfaceRenderingTests {
    @Test func secondaryWindowsAndNewSessionSheetFollowThemeChangesInPlace() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        let appearanceStore = AppAppearanceStore(userDefaults: settings.userDefaults) { _ in }
        let terminalStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let notificationStore = SessionNotificationSettingsStore(userDefaults: settings.userDefaults)
        let views: [(String, AnyView, CGSize)] = [
            ("feedback", AnyView(FeedbackView()), CGSize(width: 560, height: 640)),
            ("feedback-ready", AnyView(FeedbackView(initialDraft: FeedbackDraft(
                kind: .feature, title: "Feedback should follow the selected theme",
                details: "Buttons, links, and form controls should use the same palette as the rest of the app.",
                includesVersionInformation: false
            ))), CGSize(width: 560, height: 640)),
            ("settings", AnyView(SettingsView(
                appAppearanceStore: appearanceStore, appThemeStore: themeStore,
                terminalAppearanceStore: terminalStore, notificationSettingsStore: notificationStore
            )), CGSize(width: 560, height: 420)),
            ("new-session", AnyView(NewSessionSheet(
                initialProvider: .codex, initialHost: .thisMac, initialProjectPath: "/tmp/theme-check",
                hosts: [.thisMac], providersByHost: [.thisMac: [.codex]], recentProjects: [], onStart: { _, _, _ in }
            )), CGSize(width: 520, height: 260)),
        ]
        for (name, content, size) in views {
            for colorScheme in [ColorScheme.light, .dark] {
                let fixture = ThemeSurfaceRenderingFixture(
                    content: AnyView(content.appTheme(from: themeStore).overlay(alignment: .bottom) {
                        ReferenceThemeSurface(themeStore: themeStore).frame(height: 4)
                    }), size: size, colorScheme: colorScheme
                )
                defer { fixture.close() }
                for theme in AppTheme.allCases {
                    themeStore.setTheme(theme)
                    let bitmap = try await fixture.capture(named: "\(name)-\(theme.rawValue)-\(colorScheme)")
                    // Compare pixels rendered through the same display profile instead of unconverted RGB bytes.
                    let referencePixel = try #require(bitmap.colorAt(x: bitmap.pixelsWide / 6, y: bitmap.pixelsHigh - 2))
                    let expectedColor = hexValue(of: referencePixel)
                    let pixel = try #require(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh - 20))
                    let actualColor = hexValue(of: pixel)
                    #expect(actualColor == expectedColor, "\(name) \(theme) \(colorScheme): surface \(String(actualColor, radix: 16))")
                    if name.hasPrefix("feedback") {
                        try checkFeedbackControls(bitmap, isReady: name == "feedback-ready", description: "\(theme) \(colorScheme)")
                    }
                }
            }
        }
    }

    private func checkFeedbackControls(_ bitmap: NSBitmapImageRep, isReady: Bool, description: String) throws {
        let referenceRow = bitmap.pixelsHigh - 2
        let raisedSurface = hexValue(of: try #require(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: referenceRow)))
        let ink = hexValue(of: try #require(bitmap.colorAt(x: bitmap.pixelsWide * 5 / 6, y: referenceRow)))
        let renderingScale = Double(bitmap.pixelsWide) / 560
        // The details editor fills the lower middle of the window; its exact position moves with the header copy.
        let editorRows = (bitmap.pixelsHigh * 45 / 100)..<(bitmap.pixelsHigh * 70 / 100)
        let editorPixels = matchingPixelCount(raisedSurface, in: bitmap, columns: (bitmap.pixelsWide / 3)..<(bitmap.pixelsWide * 2 / 3), rows: editorRows)
        #expect(editorPixels > Int(150 * 60 * renderingScale * renderingScale), "\(description) editor surface")

        let edgeInset = Int(20 * renderingScale)
        let actionRows = (bitmap.pixelsHigh - Int(50 * renderingScale))..<(bitmap.pixelsHigh - Int(6 * renderingScale))
        let linkPixels = matchingPixelCount(ink, in: bitmap, columns: edgeInset..<(bitmap.pixelsWide / 3), rows: actionRows)
        #expect(linkPixels > Int(50 * renderingScale * renderingScale), "\(description) link uses theme ink")
        let buttonPixels = matchingPixelCount(ink, in: bitmap, columns: (bitmap.pixelsWide * 2 / 3)..<(bitmap.pixelsWide - edgeInset), rows: actionRows)
        let filledButtonThreshold = Int(750 * renderingScale * renderingScale)
        #expect(isReady ? buttonPixels > filledButtonThreshold : buttonPixels < filledButtonThreshold, "\(description) primary button enabled=\(isReady)")
    }

    private func matchingPixelCount(_ color: UInt32, in bitmap: NSBitmapImageRep, columns: Range<Int>, rows: Range<Int>) -> Int {
        rows.reduce(0) { count, row in
            count + columns.filter { column in
                bitmap.colorAt(x: column, y: row).map { pixel in
                    let actualColor = hexValue(of: pixel)
                    // Text rasterization can round a channel differently from the solid reference swatch.
                    return [16, 8, 0].allSatisfy { shift in
                        abs(Int((actualColor >> shift) & 0xFF) - Int((color >> shift) & 0xFF)) <= 1
                    }
                } ?? false
            }.count
        }
    }

    private func hexValue(of color: NSColor) -> UInt32 {
        [color.redComponent, color.greenComponent, color.blueComponent].reduce(0) { result, component in
            result << 8 | UInt32((component * 255).rounded())
        }
    }
}

private struct ReferenceThemeSurface: View {
    @ObservedObject var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeStore.theme.colors(isDark: colorScheme == .dark)
        HStack(spacing: 0) {
            ForEach([colors.contentSurface, colors.raisedSurface, colors.ink], id: \.self) { hexValue in
                Color(.sRGB, red: Double((hexValue >> 16) & 0xFF) / 255,
                      green: Double((hexValue >> 8) & 0xFF) / 255, blue: Double(hexValue & 0xFF) / 255)
            }
        }
    }
}
