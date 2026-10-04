/// What macOS says about one `AppPermission`.
enum AppPermissionStatus: Equatable, Sendable {
    case allowed
    case notAllowed
    /// macOS asks the first time the app needs it, and hasn't yet.
    case notAskedYet
    /// macOS gives apps no way to check, or the app runs without its bundle, as in tests.
    case unknown
}
