import SwiftUI

/// SwiftUI keeps a dialog's field from one opening to the next and fills it only when its text differs from what the
/// field last showed, so a dialog reopened on the same name showed an empty field. The field takes `openCount` as its
/// identity, so each opening gets a new one, and it shows the name shown now until you type.
struct RenameDialogs: ViewModifier {
    let store: ConversationStore
    @Binding var conversation: Conversation?
    @Binding var project: ProjectConversationGroup?
    let openCount: Int
    @State private var typedTitle: String?
    @State private var typedProjectName: String?

    private var title: Binding<String> {
        Binding(get: { typedTitle ?? conversation.map(store.title(for:)) ?? "" }, set: { typedTitle = $0 })
    }

    private var projectName: Binding<String> {
        Binding(get: { typedProjectName ?? project?.displayName ?? "" }, set: { typedProjectName = $0 })
    }

    func body(content: Content) -> some View {
        content
            .alert("Rename conversation", isPresented: Binding(isPresenting: $conversation)) {
                TextField("Name", text: title).id(openCount)
                Button("Cancel", role: .cancel) { conversation = nil }
                Button("Save") {
                    if let conversation { store.rename(conversation, to: title.wrappedValue) }
                    conversation = nil
                }
            } message: {
                Text("This changes the display name in JustSessions.")
            }
            .dismissesOnClickOutside(item: $conversation)
            .alert("Rename project", isPresented: Binding(isPresenting: $project)) {
                TextField("Name", text: projectName).id(openCount)
                Button("Cancel", role: .cancel) { project = nil }
                Button("Save") {
                    if let project { store.renameProject(project.projectPath, to: projectName.wrappedValue) }
                    project = nil
                }
            } message: {
                Text("Only renames it in JustSessions. Leave empty to use the folder name (\(project?.folderName ?? "")).")
            }
            .dismissesOnClickOutside(item: $project)
            .onChange(of: conversation?.id) { typedTitle = nil }
            .onChange(of: project?.id) { typedProjectName = nil }
    }
}
