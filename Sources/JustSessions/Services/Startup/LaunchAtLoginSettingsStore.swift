import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginSettingsStore: ObservableObject {
    static let shared = LaunchAtLoginSettingsStore()

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorDescription: String?
    private let service: any LaunchAtLoginService

    init(service: any LaunchAtLoginService = SystemLaunchAtLoginService()) {
        self.service = service
        status = service.status
    }

    /// A pending registration stays selected so it can also be turned off while awaiting approval.
    var launchesAtLogin: Bool {
        status == .enabled || status == .requiresApproval
    }

    func refreshStatus() {
        status = service.status
    }

    func setLaunchesAtLogin(_ isOn: Bool) {
        refreshStatus()
        errorDescription = nil
        guard isOn != launchesAtLogin else { return }

        do {
            if isOn {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorDescription = error.localizedDescription
        }
        // Registration can require approval or fail; never infer success from the requested value.
        refreshStatus()
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }
}
