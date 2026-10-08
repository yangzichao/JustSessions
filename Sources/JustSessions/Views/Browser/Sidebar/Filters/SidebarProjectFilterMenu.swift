import SwiftUI

/// Waiting, time, and tool filters apply only to the project library, never to open terminals.
struct SidebarProjectFilterMenu: View {
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    @Binding var waitingFilter: SessionWaitingFilter
    /// Tools installed on a host or with listed sessions; the menu offers only these.
    let offeredProviders: Set<ConversationProvider>
    let allSessionCount: Int
    let recentSessionCount: Int
    let waitingSessionCount: Int

    private var isFiltering: Bool {
        recencyFilter != .all || providerFilter.provider != nil || waitingFilter != .all
    }

    private var isWaitingForYouOnly: Binding<Bool> {
        Binding(
            get: { waitingFilter == .waitingForYou },
            set: { waitingFilter = $0 ? .waitingForYou : .all }
        )
    }

    /// Shows the chosen tool's icon on a tinted chip while it filters the list,
    /// so the filter stays visible without opening the menu.
    var body: some View {
        let filteredProvider = providerFilter.provider

        return Menu {
            Toggle(isOn: isWaitingForYouOnly) {
                Text("Waiting for you") + Text(verbatim: " · \(waitingSessionCount.formatted())")
            }
            Divider()
            Picker("Time range", selection: $recencyFilter) {
                (Text("All time") + Text(verbatim: " · \(allSessionCount.formatted())"))
                    .tag(SessionRecencyFilter.all)
                (Text("Last 7 days") + Text(verbatim: " · \(recentSessionCount.formatted())"))
                    .tag(SessionRecencyFilter.recent)
            }
            .pickerStyle(.inline)
            Divider()
            Picker("Tool", selection: $providerFilter) {
                ForEach(ConversationProviderFilter.choices(offering: offeredProviders, selected: providerFilter)) { filter in
                    if let provider = filter.provider {
                        Text(verbatim: provider.rawValue).tag(filter)
                    } else {
                        Text("All tools").tag(filter)
                    }
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            if isFiltering {
                Divider()
                Button("Clear filters") {
                    recencyFilter = .all
                    providerFilter = .all
                    waitingFilter = .all
                }
            }
        } label: {
            if let filteredProvider {
                filteredProvider.iconImage()
            } else {
                Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
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
        .overlay(alignment: .topTrailing) {
            // The tool's icon takes the chip, so a dot tells that another filter is on too.
            if recencyFilter == .recent || waitingFilter != .all, filteredProvider != nil {
                Circle().fill(.primary).frame(width: 4, height: 4)
            }
        }
        .help(isFiltering ? "Project filters are active" : "Filter project sessions")
        .accessibilityLabel("Filter project sessions")
        .accessibilityValue(isFiltering ? Text("Filters active") : Text("All sessions"))
        .accessibilityIdentifier("sidebar.projectFilters")
    }
}
