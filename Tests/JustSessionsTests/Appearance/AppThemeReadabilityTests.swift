import Foundation
import Testing
@testable import JustSessions

/// Guards against a mistyped color leaving text unreadable. The limits are WCAG contrast ratios.
struct AppThemeReadabilityTests {
    @Test func everyThemeKeepsTextReadableInLightAndDark() {
        for theme in AppTheme.allCases {
            for isDark in [false, true] {
                let colors = theme.colors(isDark: isDark)
                let terminal = colors.terminal
                let variant = "\(theme) \(isDark ? "dark" : "light")"

                #expect(terminal.ansiHexColors.count == 16, "\(variant)")
                // Tokyo Night Day's body text is the palest of these, just above 4.5.
                #expect(contrastRatio(terminal.foreground, colors.contentSurface) >= 4.5, "\(variant) terminal text")
                #expect(contrastRatio(terminal.selectionForeground, terminal.selectionBackground) >= 3, "\(variant) selection")
                // Bright black carries hints and dim text in many CLIs, so it must not vanish into the background.
                #expect(contrastRatio(terminal.ansiHexColors[8], colors.contentSurface) >= 1.5, "\(variant) bright black")
                #expect(contrastRatio(colors.inkForeground, colors.ink) >= 4.5, "\(variant) ink foreground")
            }
        }
    }

    @Test func everyTextColorIsReadableOnEverySurfaceTextSitsOn() {
        for theme in AppTheme.allCases {
            for isDark in [false, true] {
                let colors = theme.colors(isDark: isDark)
                var textColors: [(String, UInt32)] = [
                    ("ink", colors.ink),
                    ("secondary", colors.secondaryText),
                    ("tertiary", colors.tertiaryText),
                    ("warning", colors.warningText),
                    ("error", colors.errorText),
                ]
                textColors += ConversationProvider.allCases.map { ($0.rawValue, colors.providerTextHexColors[$0] ?? 0) }
                for (name, textColor) in textColors {
                    for surface in colors.textSurfaces {
                        let ratio = contrastRatio(textColor, surface)
                        #expect(ratio >= 4.5, "\(theme) dark=\(isDark) \(name) on \(String(surface, radix: 16)): \(ratio)")
                    }
                }
            }
        }
    }

    /// The check a customized theme must pass agrees with the tests above.
    @Test func everyThemeSuitsItsOwnAppearanceAndNotTheOther() {
        for theme in AppTheme.allCases {
            #expect(theme.colors(isDark: false).suits(isDark: false), "\(theme) light")
            #expect(theme.colors(isDark: true).suits(isDark: true), "\(theme) dark")
            #expect(!theme.colors(isDark: false).suits(isDark: true), "\(theme) light as dark")
        }
    }

    @Test func textSurfacesIncludeTheFaintFillsAndSelectedRows() {
        let colors = AppTheme.atomOne.colors(isDark: false)
        let hoveredRow = ThemeColorContrast.blend(colors.sidebarSurface, with: colors.line, fraction: ThemeFillOpacity.hover)
        let selectedClaudeRow = ThemeColorContrast.blend(
            colors.sidebarSurface, with: ConversationProvider.claude.tintHexColor.light, fraction: ThemeFillOpacity.selectedRow
        )

        #expect(colors.textSurfaces.contains(colors.sidebarSurface))
        #expect(colors.textSurfaces.contains(colors.userMessageSurface))
        #expect(colors.textSurfaces.contains(hoveredRow))
        #expect(colors.textSurfaces.contains(selectedClaudeRow))
    }

    @Test func tertiaryTextStaysFainterThanSecondaryText() {
        for theme in AppTheme.allCases {
            for isDark in [false, true] {
                let colors = theme.colors(isDark: isDark)
                #expect(
                    contrastRatio(colors.tertiaryText, colors.contentSurface) <= contrastRatio(colors.secondaryText, colors.contentSurface),
                    "\(theme) dark=\(isDark)"
                )
            }
        }
    }

    @Test func projectLabelsStayReadableOnTheirNormalAndHoveredBackgrounds() {
        for theme in AppTheme.allCases {
            for isDark in [false, true] {
                let colors = theme.colors(isDark: isDark)
                #expect(colors.tabGroupHexColors.count == 8)
                // The tab bar's labels sit on the sidebar surface, and the open tabs list names groups in the sidebar.
                for surface in [colors.contentSurface, colors.sidebarSurface] {
                    for foreground in colors.tabGroupHexColors {
                        for fillOpacity in [0.0, 0.15, 0.24] {
                            let background = [16, 8, 0].reduce(UInt32(0)) { result, shift in
                                let surfaceChannel = Double((surface >> shift) & 0xFF)
                                let foregroundChannel = Double((foreground >> shift) & 0xFF)
                                let channel = UInt32((surfaceChannel * (1 - fillOpacity) + foregroundChannel * fillOpacity).rounded())
                                return result << 8 | channel
                            }
                            #expect(contrastRatio(foreground, background) >= 4.5, "\(theme) dark=\(isDark) fill=\(fillOpacity)")
                        }
                    }
                }
                // The open tabs list names a group in its color on a sidebar row, which the pointer fills faintly.
                let hoveredHeading = ThemeColorContrast.blend(colors.sidebarSurface, with: colors.line, fraction: ThemeFillOpacity.hover)
                for foreground in colors.tabGroupHexColors {
                    #expect(contrastRatio(foreground, hoveredHeading) >= 4.5, "\(theme) dark=\(isDark) hovered heading")
                }
            }
        }
    }

    private func contrastRatio(_ first: UInt32, _ second: UInt32) -> Double {
        let luminances = [first, second].map(relativeLuminance).sorted()
        return (luminances[1] + 0.05) / (luminances[0] + 0.05)
    }

    private func relativeLuminance(_ hexValue: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift -> Double in
            let encoded = Double((hexValue >> UInt32(shift)) & 0xFF) / 255
            return encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
