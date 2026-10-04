import SwiftUI

extension OnboardingTourStop {
    var title: LocalizedStringKey {
        switch self {
        case .noSessionsYet: "Your sessions will appear here"
        case .projects: "Your sessions, already here"
        case .sessions: "Read first, then resume"
        case .newSession: "Start something new"
        case .sshHosts: "Sessions on other machines"
        case .keepRunning: "Close the tab, keep the CLI"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .noSessionsYet:
            "Once Claude Code, Codex, or another supported CLI saves a conversation, it shows up here, grouped by project."
        case .projects:
            "JustSessions read the history your CLIs keep and grouped it by project. Nothing was imported or uploaded."
        case .sessions:
            "Click a session to read it; nothing runs. Double-click it to continue in its CLI, in the original folder."
        case .newSession:
            "Start a session in any installed CLI, or open a plain terminal, in a project folder. ⌘N does the same."
        case .sshHosts:
            "Add a server you reach with passwordless SSH to browse and resume its sessions here."
        case .keepRunning:
            "When you close this tab, choose **Keep running**: the CLI carries on, even after you quit. Click its session to return."
        }
    }

    /// The side of its control a tip opens on: below the controls at the top of the window, so the tip stays inside it,
    /// and beside the sidebar's other controls, into the window.
    var tipEdge: Edge {
        switch self {
        case .newSession, .keepRunning: .bottom
        case .noSessionsYet, .projects, .sessions, .sshHosts: .trailing
        }
    }
}
