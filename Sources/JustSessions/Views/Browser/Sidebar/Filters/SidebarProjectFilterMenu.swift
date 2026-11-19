import SwiftUI

struct SidebarProjectFilterMenu: View {
    @Binding var recencyFilter: SessionRecencyFilter
    @Binding var providerFilter: ConversationProviderFilter
    @Binding var statusFilter: SessionStatusFilter
    @Binding var archiveFilter: SessionArchiveFilter
    let offeredProviders: Set<ConversationProvider>
    let allSessionCount: Int
    let recentSessionCount: Int
    let runningSessionCount: Int
    let waitingSessionCount: Int
    let archivedSessionCount: Int
    @Environment(\.self) private var environment

    private var isFiltering: Bool {
        recencyFilter != .all || providerFilter.provider != nil || statusFilter != .all || archiveFilter != .hideArchived
    }

    private var showsArchived: Binding<Bool> {
        Binding(
            get: { archiveFilter == .showArchived },
            set: { archiveFilter = $0 ? .showArchived : .hideArchived }
        )
    }

    private func isStatusOnly(_ status: SessionStatusFilter) -> Binding<Bool> {
        Binding(
            get: { statusFilter == status },
            set: { statusFilter = $0 ? status : .all }
        )
    }

    var body: some View {
        let filteredProvider = providerFilter.provider

        return Menu {
            Toggle(isOn: isStatusOnly(.running)) {
                Text("Running") + Text(verbatim: " · \(runningSessionCount.formatted())")
            }
            Toggle(isOn: isStatusOnly(.waitingForYou)) {
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
            Divider()
            Toggle(isOn: showsArchived) {
                Text("Show archived") + Text(verbatim: " · \(archivedSessionCount.formatted())")
            }
            if isFiltering {
                Divider()
                Button("Clear filters") {
                    recencyFilter = .all
                    providerFilter = .all
                    statusFilter = .all
                    archiveFilter = .hideArchived
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
        .foregroundStyle(filteredProvider?.tintColor ?? Color(ThemePalette.secondaryText.resolve(in: environment)))
        .frame(width: InterfaceScale.points(26), height: InterfaceScale.points(26))
        .background(
            filteredProvider.map { AnyShapeStyle($0.tintColor.opacity(0.15)) } ?? AnyShapeStyle(ThemePalette.trackFill),
            in: RoundedRectangle(.control)
        )
        .overlay(alignment: .topTrailing) {
            if recencyFilter == .recent || statusFilter != .all || archiveFilter != .hideArchived, filteredProvider != nil {
                Circle().fill(.foreground).frame(width: InterfaceScale.points(4), height: InterfaceScale.points(4))
            }
        }
        .help(isFiltering ? "Project filters are active" : "Filter project sessions")
        .accessibilityLabel("Filter project sessions")
        .accessibilityValue(isFiltering ? Text("Filters active") : Text("All sessions"))
        .accessibilityIdentifier("sidebar.projectFilters")
    }
}
