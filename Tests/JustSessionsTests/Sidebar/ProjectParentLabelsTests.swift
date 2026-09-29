import Testing
@testable import JustSessions

struct ProjectParentLabelsTests {
    @Test func projectsSharingANameShowTheirParentFolders() {
        let projects = ProjectConversationGroup.grouped([
            .fixture(projectPath: "/Users/me/code/work/app"),
            .fixture(projectPath: "/Users/me/code/personal/app"),
            .fixture(projectPath: "/Users/me/code/work/site"),
        ])

        #expect(labelsByFolderPath(projects) == [
            "/Users/me/code/work/app": "code/work",
            "/Users/me/code/personal/app": "code/personal",
        ])
    }

    @Test func aCustomNameThatMatchesAnotherProjectsNameAddsLabelsToBoth() {
        let projects = ProjectConversationGroup.grouped(
            [.fixture(projectPath: "/Users/me/code/api"), .fixture(projectPath: "/Users/me/old/backend")],
            displayNames: ProjectDisplayNames(customNamesByProjectPath: ["/Users/me/old/backend": "api"])
        )

        #expect(labelsByFolderPath(projects) == [
            "/Users/me/code/api": "me/code",
            "/Users/me/old/backend": "me/old",
        ])
    }

    @Test func projectsOnAnSSHHostAreLabelledWithTheirPathThere() {
        let projects = ProjectConversationGroup.grouped([
            .fixture(projectPath: "/home/me/work/app", host: .ssh("devbox")),
            .fixture(projectPath: "/srv/app", host: .ssh("devbox")),
        ])

        #expect(labelsByFolderPath(projects) == [
            "/home/me/work/app": "me/work",
            "/srv/app": "srv",
        ])
    }

    @Test func aProjectAtTheTopOfTheDiskIsLabelledWithTheRoot() {
        #expect(ProjectParentLabels.parentLabel(forFolderPath: "/app") == "/")
    }

    /// Each labelled project's label, keyed by its folder path on its host.
    private func labelsByFolderPath(_ projects: [ProjectConversationGroup]) -> [String: String] {
        let labels = ProjectParentLabels(projectsOnOneHost: projects)
        return projects.reduce(into: [:]) { labelsByFolderPath, project in
            labelsByFolderPath[project.location.path] = labels.label(for: project)
        }
    }
}
