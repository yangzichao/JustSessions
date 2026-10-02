import SwiftUI

struct TranscriptSearchBar: View {
    @Bindable var searchState: TranscriptSearchState
    let hasOmittedEntries: Bool
    @FocusState private var isFieldFocused: Bool

    private var localizedResultLabel: LocalizedStringKey {
        if searchState.isSearching { return "Searching…" }
        if searchState.query.isEmpty { return "" }
        guard let index = searchState.selectedMatchIndex else { return "No matches" }
        return "\(index + 1) of \(searchState.matches.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(ThemePalette.secondaryText)
                    TextField("Find in conversation", text: $searchState.query)
                        .textFieldStyle(.plain)
                        .focused($isFieldFocused)
                        .accessibilityIdentifier("preview.search-field")
                        .onSubmit { searchState.move(forward: true) }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ThemePalette.hairline))
                Text(localizedResultLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize()
                    .accessibilityIdentifier("preview.search-count")
                HStack(spacing: 10) {
                    Button("Previous match", systemImage: "chevron.up") { searchState.move(forward: false) }
                        .help("Previous match (⇧⌘G or ⇧Return)")
                    Button("Next match", systemImage: "chevron.down") { searchState.move(forward: true) }
                        .help("Next match (⌘G or Return)")
                }
                .disabled(searchState.matches.isEmpty || searchState.isSearching)
                Button("Close search", systemImage: "xmark", action: searchState.close)
                    .help("Close search (Escape)")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            if hasOmittedEntries {
                Text("Search covers the entries shown in this preview.")
                    .font(.caption)
                    .foregroundStyle(ThemePalette.secondaryText)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(ThemePalette.ink)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .accessibilityIdentifier("preview.search-bar")
        .onAppear { isFieldFocused = true }
        .onChange(of: searchState.focusRevision) { isFieldFocused = true }
        .onChange(of: isFieldFocused) { searchState.isFieldFocused = isFieldFocused }
        .onDisappear { searchState.isFieldFocused = false }
        .onExitCommand(perform: searchState.close)
    }
}
