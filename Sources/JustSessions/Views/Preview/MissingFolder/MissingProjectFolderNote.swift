import SwiftUI

/// Under a session's header while its project folder is gone from this Mac, moved or renamed after the session ran.
/// Resume and Branch start the CLI in that folder, so they stay off until it is back, and this says why.
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
        .font(.callout)
        .foregroundStyle(ThemePalette.warningText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayedPath: String {
        (projectPath as NSString).abbreviatingWithTildeInPath
    }
}
