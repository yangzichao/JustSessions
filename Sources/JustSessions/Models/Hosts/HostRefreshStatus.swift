import Foundation

enum HostRefreshStatus: Equatable {
    case refreshing
    case refreshed(Date)
    case failed(String)
}
