import SwiftUI

struct TerminalFindBar: View {
    @Bindable var findState: TerminalFindState
    @FocusState private var isFieldFocused: Bool

    static var width: CGFloat { InterfaceScale.points(340) }

    private var localizedResultLabel: LocalizedStringKey {
        guard !findState.query.isEmpty, let matchCount = findState.matchCount else { return "" }
        if matchCount.total == 0 { return "No matches" }
        if let selectedNumber = matchCount.selectedNumber { return "\(selectedNumber) of \(matchCount.total)" }
        if matchCount.exceedsCountLimit { return "\(matchCount.total)+ matches" }
        return "\(matchCount.total) matches"
    }

    private var shape: RoundedRectangle { RoundedRectangle(.card) }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(ThemePalette.secondaryText)
                TextField("Find in terminal", text: $findState.query)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .accessibilityIdentifier("terminal.find-field")
                Text(localizedResultLabel)
                    .font(ThemeFont.caption.monospacedDigit())
                    .foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize()
                    .accessibilityIdentifier("terminal.find-count")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ThemePalette.contentSurface, in: RoundedRectangle(.control))
            .overlay(RoundedRectangle(.control).strokeBorder(ThemePalette.hairline))
            HStack(spacing: 4) {
                Button("Older match", systemImage: "chevron.up") { findState.move(.towardOlder) }
                    .help("Older match (⌘G or Return)")
                Button("Newer match", systemImage: "chevron.down") { findState.move(.towardNewer) }
                    .help("Newer match (⇧⌘G or ⇧Return)")
            }
            .disabled(findState.query.isEmpty || findState.matchCount?.total == 0)
            Button("Close search", systemImage: "xmark", action: findState.close)
                .help("Close search (Escape)")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 4, verticalPadding: 4))
        .font(ThemeFont.body)
        .foregroundStyle(ThemePalette.ink)
        .padding(6)
        .frame(maxWidth: Self.width)
        .background {
            shape
                .fill(ThemePalette.raisedSurface)
                .themeShadow(.floating)
        }
        .overlay { shape.strokeBorder(ThemePalette.hairline) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("terminal.find-bar")
        .onAppear { isFieldFocused = true }
        .onChange(of: findState.focusRevision) { isFieldFocused = true }
        .onChange(of: isFieldFocused) { findState.isFieldFocused = isFieldFocused }
        .onDisappear { findState.isFieldFocused = false }
    }
}
