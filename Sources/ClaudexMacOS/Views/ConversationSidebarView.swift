import SwiftUI

struct ConversationSidebarView: View {
    @Binding var searchText: String
    let selection: ConversationBrowserSelection
    let projects: [ProjectConversationGroup]
    let conversationCount: Int
    let recentCount: Int
    let onSelect: (ConversationBrowserSelection) -> Void

    private var repeatedProjectNames: Set<String> {
        Set(Dictionary(grouping: projects, by: \.projectName)
            .filter { $0.value.count > 1 }
            .map(\.key))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Claudex").font(.system(size: 15, weight: .semibold))
                    Text("SESSION LIBRARY")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 18)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search sessions", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search sessions and projects")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Clear search")
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
            .padding(.horizontal, 12)

            VStack(spacing: 2) {
                navigationRow("All sessions", symbol: "square.stack", count: conversationCount, isSelected: selection == .all) {
                    onSelect(.all)
                }
                navigationRow("Recent", symbol: "clock", count: recentCount, isSelected: selection == .recent) {
                    onSelect(.recent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 18)

            HStack {
                Text("PROJECTS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                Spacer()
                Text("\(projects.count)")
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.top, 26)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(projects) { project in
                        navigationRow(
                            project.projectName,
                            symbol: "folder",
                            count: project.conversations.count,
                            isSelected: selection == .project(project.id),
                            subtitle: repeatedProjectNames.contains(project.projectName)
                                ? projectParentLabel(project.projectPath) : nil
                        ) {
                            onSelect(.project(project.id))
                        }
                        .help(project.projectPath)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 14)
            }

            Divider()
            Text("Claude Code  ·  Codex")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
        }
        .frame(width: 248)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func navigationRow(
        _ title: String,
        symbol: String,
        count: Int,
        isSelected: Bool,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .frame(width: 17)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .frame(height: subtitle == nil ? 32 : 42)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private func projectParentLabel(_ projectPath: String) -> String {
        let parent = URL(fileURLWithPath: projectPath).deletingLastPathComponent()
        return parent.pathComponents.suffix(2).joined(separator: "/")
    }
}
