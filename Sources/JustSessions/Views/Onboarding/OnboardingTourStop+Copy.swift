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
        case .resume: "Pick up where you left off"
        case .findInConversation: "Find in this conversation"
        case .sessionMenu: "More in the right-click menu"
        case .searchSessions: "Find any session"
        case .tabGroup: "Tabs grouped by project"
        case .hideSidebar: "More room for the terminal"
        case .openTabs: "Every open tab in one list"
        case .splitView: "Two tabs side by side"
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
        case .resume:
            "**Resume** continues this conversation in its CLI, in its original folder. Double-clicking the session in the sidebar does the same."
        case .findInConversation:
            "Search the text of the conversation you are reading. ⌘F does the same."
        case .sessionMenu:
            "Right-click a session to rename, pin, export, or delete it. ⌘-click or Shift-click to select several at once."
        case .searchSessions:
            "Search projects by name or path, and sessions by title, ID, or message text."
        case .tabGroup:
            "Click the project's name to collapse its tabs. A collapsed group still shows when a CLI is waiting on you."
        case .hideSidebar:
            "Hide the sidebar to give the terminal the whole window, and click again to bring it back. ⌘B does the same."
        case .openTabs:
            "**Open tabs** lists every tab with what its CLI is doing. ⌘1 to ⌘8 go to a tab by its position, and ⌘9 to the last."
        case .splitView:
            "Right-click another tab and choose **New split view with current tab**. Drag between the two views to resize them."
        }
    }

    /// The side of its control a tip opens on: below the controls at the top of the window, so the tip stays inside it,
    /// and beside the sidebar's other controls, into the window.
    var tipEdge: Edge {
        switch self {
        case .newSession, .keepRunning, .resume, .findInConversation, .searchSessions, .tabGroup, .hideSidebar, .splitView: .bottom
        case .noSessionsYet, .projects, .sessions, .sshHosts, .sessionMenu, .openTabs: .trailing
        }
    }
}
