import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
struct ThemeSegmentedPickerRenderingTests {
    /// The system segmented control's selected segment differed from its track by about 1.1:1 on Atom One Dark's
    /// Settings surface. A selected segment is a control's state, so it needs the 3:1 of WCAG's non-text contrast.
    @Test func selectedSegmentStandsOutFromTheTrackInEveryTheme() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        let size = CGSize(width: 240, height: 40)
        let pickerFrame = CGRect(x: 20, y: 0, width: 200, height: size.height)
        let picker = ThemeSegmentedPicker(
            "Engine", selection: .constant(TerminalEngine.swiftTerm),
            segments: [
                ThemeSegment(value: TerminalEngine.swiftTerm, title: Text(verbatim: "SwiftTerm")),
                ThemeSegment(value: TerminalEngine.ghostty, title: Text(verbatim: "Ghostty")),
            ]
        )
        .frame(width: pickerFrame.width)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemePalette.contentSurface)

        for colorScheme in [ColorScheme.light, .dark] {
            let fixture = ThemeSurfaceRenderingFixture(
                content: AnyView(picker.appTheme(from: themeStore)), size: size, colorScheme: colorScheme
            )
            defer { fixture.close() }
            for theme in AppTheme.allCases {
                themeStore.setTheme(theme)
                let bitmap = try await fixture.capture(named: "segmented-\(theme.rawValue)-\(colorScheme)")
                let renderingScale = Double(bitmap.pixelsWide) / size.width
                func color(atPoint x: CGFloat) throws -> UInt32 {
                    let pixel = try #require(
                        bitmap.colorAt(
                            x: Int(x * renderingScale), y: Int(size.height / 2 * renderingScale)
                        ))
                    return hexValue(of: pixel)
                }
                // Just inside each end of the control, clear of its rounded corners and centered titles.
                let selectedFill = try color(atPoint: pickerFrame.minX + 6)
                let track = try color(atPoint: pickerFrame.maxX - 6)
                let contrast = ThemeColorContrast.ratio(selectedFill, track)
                #expect(contrast >= 3, "\(theme) \(colorScheme): selected segment is \(contrast):1 on its track")
            }
        }
    }

    private func hexValue(of color: NSColor) -> UInt32 {
        [color.redComponent, color.greenComponent, color.blueComponent].reduce(0) { result, component in
            result << 8 | UInt32((component * 255).rounded())
        }
    }
}
