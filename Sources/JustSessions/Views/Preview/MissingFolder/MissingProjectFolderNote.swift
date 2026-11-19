import SwiftUI

struct MissingProjectFolderNote: View {
    let projectPath: String

    var body: some View {
        Label {
            Text("The project folder is no longer at \(displayedPath). Move it back there to resume this session.")
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "folder.badge.questionmark")
        }
        .font(ThemeFont.callout)
        .foregroundStyle(ThemePalette.warningText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayedPath: String {
        (projectPath as NSString).abbreviatingWithTildeInPath
    }
}
