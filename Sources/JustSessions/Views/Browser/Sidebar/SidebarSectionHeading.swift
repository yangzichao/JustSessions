import SwiftUI

/// Small uppercase label above a sidebar section, with the number of items in it.
struct SidebarSectionHeading: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Spacer()
            Text(count.formatted())
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 10, weight: .semibold))
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }
}
