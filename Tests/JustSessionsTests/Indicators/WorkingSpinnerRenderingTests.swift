import AppKit
import Foundation
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
struct WorkingSpinnerRenderingTests {
    private static let size = CGSize(width: 40, height: 24)
    private static let swatchSide: CGFloat = 8

    @Test(arguments: [ColorScheme.light, .dark])
    func theArcDrawsInTheLiveColorOfTheAppearance(colorScheme: ColorScheme) async throws {
        let fixture = ThemeSurfaceRenderingFixture(
            content: AnyView(
                HStack(spacing: 8) {
                    SessionStatusIndicator(status: .running(.working))
                    Rectangle().fill(ThemePalette.live).frame(width: Self.swatchSide, height: Self.swatchSide)
                }
                .padding(7)
                .background(ThemePalette.sidebarSurface)
            ),
            size: Self.size,
            colorScheme: colorScheme
        )
        defer { fixture.close() }
        let schemeName = colorScheme == .dark ? "dark" : "light"

        let bitmap = try await fixture.capture(named: "working-spinner-\(schemeName)")

        let scale = Double(bitmap.pixelsHigh) / Self.size.height
        let swatchCenter = try #require(bitmap.colorAt(x: Int(29 * scale), y: Int(12 * scale))).sRGBHexValue
        let liveHexValue = try #require(swatchCenter)
        let corner = try #require(bitmap.colorAt(x: 0, y: 0)).sRGBHexValue
        let backgroundHexValue = try #require(corner)
        var livePixels = 0
        var liveCoverage = 0.0
        for row in 0..<bitmap.pixelsHigh {
            for column in 0..<bitmap.pixelsWide {
                guard let hexValue = bitmap.colorAt(x: column, y: row)?.sRGBHexValue else { continue }
                if matches(hexValue, liveHexValue) { livePixels += 1 }
                liveCoverage += share(of: liveHexValue, over: backgroundHexValue, in: hexValue)
            }
        }
        let swatchPixels = Self.swatchSide * Self.swatchSide * scale * scale
        #expect(Double(livePixels) > swatchPixels, "\(schemeName): the arc is drawn in the live color")
        let arcArea = (liveCoverage - swatchPixels) / (scale * scale)
        #expect(arcArea > 20 && arcArea < 38, "\(schemeName): only the arc is drawn (\(arcArea) square points)")
    }

    @Test func theStillArcCoversThePixelsTheSwiftUIArcDid() async throws {
        let side: CGFloat = 24
        func render(_ content: AnyView, named name: String) async throws -> NSBitmapImageRep {
            let fixture = ThemeSurfaceRenderingFixture(
                content: AnyView(content.padding(8).background(ThemePalette.sidebarSurface)),
                size: CGSize(width: side, height: side),
                colorScheme: .light
            )
            defer { fixture.close() }
            return try await fixture.capture(named: name)
        }
        let swiftUIArc = AnyView(
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(ThemePalette.live, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 8, height: 8)
        )
        let layerArc = AnyView(WorkingSpinner(holdsStill: true))

        let expected = try await render(swiftUIArc, named: "working-spinner-still-swiftui")
        let actual = try await render(layerArc, named: "working-spinner-still-layer")

        try #require(expected.pixelsWide == actual.pixelsWide && expected.pixelsHigh == actual.pixelsHigh)
        let cornerColor = try #require(expected.colorAt(x: 0, y: 0))
        let background = try #require(cornerColor.sRGBHexValue)
        var mismatches = 0
        var inkPixels = 0
        for row in 0..<expected.pixelsHigh {
            for column in 0..<expected.pixelsWide {
                let expectedInk = expected.colorAt(x: column, y: row)?.sRGBHexValue != background
                let actualInk = actual.colorAt(x: column, y: row)?.sRGBHexValue != background
                if expectedInk { inkPixels += 1 }
                if expectedInk != actualInk { mismatches += 1 }
            }
        }
        #expect(inkPixels > 0)
        #expect(mismatches <= inkPixels / 4, "\(mismatches) of \(inkPixels) arc pixels differ from the SwiftUI arc")
    }

    @Test func noViewTicksATimelineEveryFrame() throws {
        let perFrameTimeline = try Regex(#"TimelineView\s*\(\s*\.animation"#)
        let offendingFiles = try ViewSourceLines().files
            .filter { file in !file.path.hasPrefix(ViewSourceLines.themeFolder) }
            .filter { file in file.lines.joined(separator: "\n").contains(perFrameTimeline) }
            .map(\.path)
        #expect(offendingFiles.isEmpty, "Animate in a Core Animation layer instead; see WorkingSpinner: \(offendingFiles)")
    }

    private func matches(_ color: UInt32, _ reference: UInt32) -> Bool {
        [16, 8, 0].allSatisfy { shift in abs(Int((color >> shift) & 0xFF) - Int((reference >> shift) & 0xFF)) <= 6 }
    }

    private func share(of reference: UInt32, over background: UInt32, in color: UInt32) -> Double {
        func channels(_ value: UInt32) -> [Double] { [16, 8, 0].map { shift in Double((value >> shift) & 0xFF) } }
        let towardReference = zip(channels(reference), channels(background)).map { $0 - $1 }
        let offset = zip(channels(color), channels(background)).map { $0 - $1 }
        let projection = zip(offset, towardReference).map { $0 * $1 }.reduce(0, +)
        return min(max(projection / towardReference.map { $0 * $0 }.reduce(0, +), 0), 1)
    }
}
