import AppKit
import SwiftUI
import Testing

@testable import JustSessions

/// Settings → Appearance → Interface size: what it saves, and that the app's type and the sizes that hold it follow it.
@MainActor
@Suite(.serialized)
struct InterfaceSizeTests {
    @Test func savesOnlyASizeOnAStepWithinTheRange() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = InterfaceSizeStore(userDefaults: settings.userDefaults)
        #expect(store.scale == 1.0)

        store.setScale(1.26)
        #expect(store.scale == 1.3)
        #expect(settings.userDefaults.double(forKey: InterfaceSizeStore.userDefaultsKey) == 1.3)
        #expect(InterfaceSizeStore(userDefaults: settings.userDefaults).scale == 1.3)

        store.setScale(4)
        #expect(store.scale == 1.5)
        store.setScale(0.2)
        #expect(store.scale == 0.9)
        store.setScale(.nan)
        #expect(store.scale == 1.0)
        // The default is no saved value, so a later default applies.
        #expect(settings.userDefaults.object(forKey: InterfaceSizeStore.userDefaultsKey) == nil)

        settings.userDefaults.set(1.17, forKey: InterfaceSizeStore.userDefaultsKey)
        #expect(InterfaceSizeStore(userDefaults: settings.userDefaults).scale == 1.2)
    }

    @Test func sizesFollowTheInterfaceSizeToTheHalfPoint() {
        #expect(InterfaceScale.points(28, at: 1.0) == 28)
        #expect(InterfaceScale.points(28, at: 1.3) == 36.5)
        #expect(InterfaceScale.points(7, at: 1.3) == 9)
        #expect(InterfaceScale.points(28, at: 0.9) == 25)
        #expect(InterfaceScale.controlSize(at: 0.9) == .small)
        #expect(InterfaceScale.controlSize(at: 1.0) == .regular)
        #expect(InterfaceScale.controlSize(at: 1.1) == .regular)
        #expect(InterfaceScale.controlSize(at: 1.3) == .large)
        #expect(InterfaceScale.controlSize(at: 1.5) == .extraLarge)
        // Tests run beside others that draw the app's views, so none changes the app's own size.
        #expect(InterfaceSizeStore.shared.scale == InterfaceSizeStore.defaultScale)
    }

    /// A view on screen whose body sets its text in the theme's scaled font redraws larger when its store's size
    /// changes, with nothing else telling it to. The store is the test's own, read through the same path the app's
    /// tokens read the shared one, so other tests keep drawing at the default size.
    @Test func textOnScreenGrowsWhenTheInterfaceSizeChanges() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = InterfaceSizeStore(userDefaults: settings.userDefaults)
        let label = NSHostingView(rootView: ScaledLabel(store: store))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = label
        defer { window.close() }
        let width = label.fittingSize.width

        store.setScale(1.5)
        try await expectEventually { label.fittingSize.width > width * 1.4 }

        #expect(label.fittingSize.width > width * 1.4)
    }
}

/// Reads the theme's scaled font in its body, as the app's views read `ThemeFont`'s tokens.
private struct ScaledLabel: View {
    let store: InterfaceSizeStore

    var body: some View {
        Text("Fix the login redirect loop").font(ThemeFont.scaled(12, in: store)).fixedSize()
    }
}
