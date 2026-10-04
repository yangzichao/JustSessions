/// Settings and Help, which belong to the whole app rather than one project. Each shows as a sheet on a workspace
/// window and closes like the window's other sheets, instead of staying open as a window of its own.
enum AppWideSheet: String, Identifiable {
    case settings
    case help

    var id: String { rawValue }
}
