import SwiftUI

struct HostCheckFindingRow: View {
    let finding: HostCheckFinding
    let host: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HostCheckStatusIcon(status: finding.status)
                .font(ThemeFont.body)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: finding.title)
                        .font(ThemeFont.body.weight(.medium))
                    Text(verbatim: finding.summary)
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if finding.status != .passed, let hostOutput = finding.hostOutput, !hostOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(host) printed:")
                            .font(ThemeFont.detail)
                            .foregroundStyle(ThemePalette.tertiaryText)
                        HostCheckMonospacedText(text: hostOutput)
                    }
                }
                if finding.status != .passed, let command = finding.commandToRunYourself {
                    HostCheckCommandToRunYourself(command: command)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
