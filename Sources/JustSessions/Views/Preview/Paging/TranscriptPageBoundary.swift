import SwiftUI

struct TranscriptPageBoundary: View {
    let isEarlier: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isLoading { ProgressView().controlSize(.small) }
            Button(action: action) {
                if isEarlier { Text("Load earlier messages") } else { Text("Load later messages") }
            }
            .buttonStyle(.borderless)
            .disabled(isLoading)
        }
        .font(.caption)
        .foregroundStyle(ThemePalette.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
