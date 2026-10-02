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
        let tabReopeningStore = TabReopeningSettingsStore(userDefaults: settings.userDefaults)
        let views: [(String, AnyView, CGSize)] = [
            ("help", AnyView(HelpView()), CGSize(width: 600, height: 680)),
            ("help-narrow", AnyView(HelpView()), CGSize(width: 480, height: 560)),
            ("settings", AnyView(SettingsView(
                tabReopeningSettingsStore: tabReopeningStore,
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
                    if name.hasPrefix("help") {
                        try checkHelpLinks(bitmap, viewWidth: size.width, description: "\(name) \(theme) \(colorScheme)")
                    }
                }
            }
        }
    }

    private func checkHelpLinks(_ bitmap: NSBitmapImageRep, viewWidth: CGFloat, description: String) throws {
        let referenceRow = bitmap.pixelsHigh - 2
        let ink = hexValue(of: try #require(bitmap.colorAt(x: bitmap.pixelsWide * 5 / 6, y: referenceRow)))
        let renderingScale = Double(bitmap.pixelsWide) / viewWidth
        let edgeInset = Int(20 * renderingScale)
        let actionRows = (bitmap.pixelsHigh - Int(50 * renderingScale))..<(bitmap.pixelsHigh - Int(6 * renderingScale))
        let linkPixels = matchingPixelCount(ink, in: bitmap, columns: edgeInset..<(bitmap.pixelsWide / 3), rows: actionRows)
        #expect(linkPixels > Int(50 * renderingScale * renderingScale), "\(description) guide link uses theme ink")
        let issueLinkPixels = matchingPixelCount(ink, in: bitmap, columns: (bitmap.pixelsWide * 2 / 3)..<(bitmap.pixelsWide - edgeInset), rows: actionRows)
        #expect(issueLinkPixels > Int(50 * renderingScale * renderingScale), "\(description) issue link uses theme ink")
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
