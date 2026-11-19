import Foundation

enum SidebarSSHHostLogin: Equatable {
    case notLoggedIn(needsLogIn: Bool)
    case loggingIn
    case loggedIn
    case disconnected
}
