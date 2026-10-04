import ServiceManagement

@MainActor
protocol LaunchAtLoginService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

/// macOS owns the login item and its approval, including changes made outside JustSessions.
@MainActor
struct SystemLaunchAtLoginService: LaunchAtLoginService {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
