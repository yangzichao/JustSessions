import Foundation
import ServiceManagement
import Testing
@testable import JustSessions

@MainActor
struct LaunchAtLoginSettingsStoreTests {
    @Test func startsOffWithoutRegisteringAndCanBeEnabledThenDisabled() {
        let service = TestLaunchAtLoginService()
        let store = LaunchAtLoginSettingsStore(service: service)
        #expect(!store.launchesAtLogin)
        #expect(service.registrationCount == 0)

        store.setLaunchesAtLogin(true)
        #expect(store.status == .enabled)
        #expect(store.launchesAtLogin)
        #expect(service.registrationCount == 1)

        store.setLaunchesAtLogin(false)
        #expect(store.status == .notRegistered)
        #expect(!store.launchesAtLogin)
        #expect(service.unregistrationCount == 1)
    }

    @Test func readsExistingRegistrationWithoutChangingIt() {
        let service = TestLaunchAtLoginService(status: .enabled)
        let store = LaunchAtLoginSettingsStore(service: service)
        #expect(store.launchesAtLogin)
        #expect(service.registrationCount == 0)
        #expect(service.unregistrationCount == 0)
    }

    @Test func pendingApprovalCanOpenSettingsAndBeCancelled() {
        let service = TestLaunchAtLoginService()
        service.registrationStatus = .requiresApproval
        let store = LaunchAtLoginSettingsStore(service: service)

        store.setLaunchesAtLogin(true)
        #expect(store.status == .requiresApproval)
        #expect(store.launchesAtLogin)
        #expect(service.openSettingsCount == 0)
        store.openSystemSettings()
        #expect(service.openSettingsCount == 1)

        store.setLaunchesAtLogin(false)
        #expect(store.status == .notRegistered)
        #expect(!store.launchesAtLogin)
        #expect(service.unregistrationCount == 1)
    }

    @Test func failedRegistrationKeepsToggleOffAndAllowsRetry() {
        let service = TestLaunchAtLoginService()
        service.registrationError = TestServiceError.denied
        let store = LaunchAtLoginSettingsStore(service: service)

        store.setLaunchesAtLogin(true)
        #expect(!store.launchesAtLogin)
        #expect(store.errorDescription == TestServiceError.denied.localizedDescription)

        service.registrationError = nil
        store.setLaunchesAtLogin(true)
        #expect(store.launchesAtLogin)
        #expect(store.errorDescription == nil)
        #expect(service.registrationCount == 2)
    }

    @Test func failedUnregistrationKeepsActualSystemState() {
        let service = TestLaunchAtLoginService(status: .enabled)
        service.unregistrationError = TestServiceError.denied
        let store = LaunchAtLoginSettingsStore(service: service)

        store.setLaunchesAtLogin(false)
        #expect(store.launchesAtLogin)
        #expect(store.status == .enabled)
        #expect(store.errorDescription != nil)
    }

    @Test func refreshReflectsApprovalAndRemovalInSystemSettings() {
        let service = TestLaunchAtLoginService(status: .requiresApproval)
        let store = LaunchAtLoginSettingsStore(service: service)

        service.status = .enabled
        store.refreshStatus()
        #expect(store.status == .enabled)
        #expect(store.launchesAtLogin)

        service.status = .notRegistered
        store.refreshStatus()
        #expect(!store.launchesAtLogin)
        #expect(service.registrationCount == 0)
        #expect(service.unregistrationCount == 0)
    }

    @Test func changingChoiceReadsExternalChangesBeforeRegistering() {
        let service = TestLaunchAtLoginService()
        let store = LaunchAtLoginSettingsStore(service: service)

        service.status = .enabled
        store.setLaunchesAtLogin(false)
        #expect(service.unregistrationCount == 1)
        #expect(!store.launchesAtLogin)
    }

    @Test func missingServiceDoesNotLookEnabled() {
        let service = TestLaunchAtLoginService(status: .notFound)
        let store = LaunchAtLoginSettingsStore(service: service)
        #expect(!store.launchesAtLogin)
    }
}

@MainActor
private final class TestLaunchAtLoginService: LaunchAtLoginService {
    var status: SMAppService.Status
    var registrationStatus: SMAppService.Status = .enabled
    var registrationError: (any Error)?
    var unregistrationError: (any Error)?
    private(set) var registrationCount = 0
    private(set) var unregistrationCount = 0
    private(set) var openSettingsCount = 0

    init(status: SMAppService.Status = .notRegistered) {
        self.status = status
    }

    func register() throws {
        registrationCount += 1
        if let registrationError { throw registrationError }
        status = registrationStatus
    }

    func unregister() throws {
        unregistrationCount += 1
        if let unregistrationError { throw unregistrationError }
        status = .notRegistered
    }

    func openSystemSettings() {
        openSettingsCount += 1
    }
}

private enum TestServiceError: LocalizedError {
    case denied

    var errorDescription: String? { "The login item could not be changed." }
}
