import SwiftUI

/// Recency and tool filters on one line under search, since all three narrow the same project list.
struct SidebarFilterBar: View {
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    /// Tools installed on a host or with listed sessions; the menu offers only these.
    let offeredProviders: Set<ConversationProvider>
    let allSessionCount: Int
    let recentSessionCount: Int

    var body: some View {
        HStack(spacing: 6) {
            SidebarRecencyPicker(
                selection: $recencyFilter,
                allSessionCount: allSessionCount,
                recentSessionCount: recentSessionCount
            )
            toolFilterMenu
        }
        .padding(.horizontal, 12)
    }

    /// Shows the chosen tool's icon on a tinted chip while it filters the list,
    /// so the filter stays visible without opening the menu.
    private var toolFilterMenu: some View {
        let filteredProvider = providerFilter.provider

        return Menu {
            Picker("Tool", selection: $providerFilter) {
                ForEach(ConversationProviderFilter.choices(offering: offeredProviders, selected: providerFilter)) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            if let filteredProvider {
                filteredProvider.iconImage()
            } else {
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(filteredProvider?.tintColor ?? Color.secondary)
        .frame(width: 26, height: 26)
        .background(
            filteredProvider.map { AnyShapeStyle($0.tintColor.opacity(0.15)) } ?? AnyShapeStyle(ThemePalette.trackFill),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .help(filteredProvider.map { "Showing \($0.rawValue) sessions only" } ?? "Show one tool's sessions")
        .accessibilityLabel("Tool filter: \(providerFilter.title)")
    }
}
