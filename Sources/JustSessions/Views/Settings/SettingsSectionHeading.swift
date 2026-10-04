import SwiftUI

/// A section's title across a settings grid, with an optional control at its trailing edge that acts on that section.
struct SettingsSectionHeading<Accessory: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let accessory: () -> Accessory

    init(_ title: LocalizedStringKey, @ViewBuilder accessory: @escaping () -> Accessory) {
        self.title = title
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer(minLength: 12)
            accessory()
        }
        .gridCellColumns(2)
    }
}

extension SettingsSectionHeading where Accessory == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
    }
}
