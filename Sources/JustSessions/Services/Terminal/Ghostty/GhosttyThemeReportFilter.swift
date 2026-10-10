import Foundation

/// Takes Ghostty's own light and dark theme reports out of what it sends the tab's process, since the tab sends its
/// own; see `TerminalThemeReporting`. Ghostty answers `CSI ? 996 n` and reports theme changes itself, but always says
/// light, and it reports again on each change to its configuration.
///
/// Only a whole report within one write is removed. Bytes are never held back for the next write, which would delay a
/// lone Escape key.
enum GhosttyThemeReportFilter {
    /// `CSI ? 997 ; 1 n` (dark) and `CSI ? 997 ; 2 n` (light).
    private static let reports: [[UInt8]] = [
        TerminalThemeReporting.report(isDark: true),
        TerminalThemeReporting.report(isDark: false),
    ].map { Array($0.utf8) }

    static func removingThemeReports(from bytes: Data) -> Data {
        guard bytes.contains(0x1B) else { return bytes }
        let input = [UInt8](bytes)
        var output: [UInt8] = []
        output.reserveCapacity(input.count)
        var index = 0
        while index < input.count {
            if input[index] == 0x1B, let report = reports.first(where: { input[index...].starts(with: $0) }) {
                index += report.count
            } else {
                output.append(input[index])
                index += 1
            }
        }
        return output.count == input.count ? bytes : Data(output)
    }
}
