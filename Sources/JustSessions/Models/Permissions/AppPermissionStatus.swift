enum AppPermissionStatus: Equatable, Sendable {
    case allowed
    case notAllowed
    case notAskedYet
    /// macOS gives apps no way to check, or the app runs without its bundle, as in tests.
    case unknown
}
