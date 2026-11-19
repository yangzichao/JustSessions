import SwiftUI

struct TerminalSSHFileDropNotice: View {
    @ObservedObject var fileDrop: TerminalSSHFileDrop

    static var maximumWidth: CGFloat { InterfaceScale.points(320) }
    static let marginFromTerminalEdges: CGFloat = 12

    var body: some View {
        if let status = fileDrop.status {
            Group {
                switch status {
                case .copying(let fileName, let fileNumber, let fileCount, let fractionCopied):
                    copying(fileName: fileName, fileNumber: fileNumber, fileCount: fileCount, fractionCopied: fractionCopied)
                case .failed(let explanation):
                    failed(explanation: explanation)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: Self.maximumWidth, alignment: .leading)
            .background {
                RoundedRectangle(.card)
                    .fill(ThemePalette.raisedSurface)
                    .themeShadow(.floating)
            }
            .overlay { RoundedRectangle(.card).strokeBorder(ThemePalette.hairline) }
            .padding(Self.marginFromTerminalEdges)
            .accessibilityElement(children: .contain)
        }
    }

    private func copying(fileName: String, fileNumber: Int, fileCount: Int, fractionCopied: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Copying to \(fileDrop.host)…")
                        .font(ThemeFont.callout.weight(.medium))
                        .foregroundStyle(ThemePalette.ink)
                    Group {
                        if fileCount == 1 {
                            Text(verbatim: fileName)
                        } else {
                            Text("\(fileName) (\(fileNumber) of \(fileCount))")
                        }
                    }
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .truncationMode(.middle)
                }
                .lineLimit(1)
                Spacer(minLength: 4)
                Button("Cancel", action: fileDrop.cancel)
                    .buttonStyle(QuietBorderedButtonStyle())
                    .controlSize(.small)
                    .help("Stop copying; nothing is typed")
                    .accessibilityLabel("Cancel copying")
            }
            ProgressView(value: fractionCopied)
                .progressViewStyle(.linear)
                .controlSize(.small)
                .accessibilityLabel("Copying dropped files to \(fileDrop.host)")
        }
    }

    private func failed(explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Label("Couldn't copy to \(fileDrop.host)", systemImage: "exclamationmark.triangle")
                    .font(ThemeFont.callout.weight(.medium))
                    .foregroundStyle(ThemePalette.warningText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button(action: fileDrop.dismissFailure) {
                    Image(systemName: "xmark")
                        .font(ThemeFont.glyph(.control, weight: .semibold))
                        .foregroundStyle(ThemePalette.secondaryText)
                        .frame(width: InterfaceScale.points(22), height: InterfaceScale.points(22))
                        .contentShape(Circle())
                }
                .buttonStyle(ThemePlainButtonStyle(cornerRadius: nil))
                .help("Close")
                .accessibilityLabel("Close")
            }
            Text(verbatim: explanation)
                .font(ThemeFont.callout)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}
