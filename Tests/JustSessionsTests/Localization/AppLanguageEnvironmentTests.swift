import AppKit
import Combine
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
struct AppLanguageEnvironmentTests {
    @Test func languageChangesReachExistingViewsWithoutReplacingTheirState() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppLanguageStore(userDefaults: settings.userDefaults)
        store.setLanguage(AppInterfaceLanguage(identifier: "en"))
        var observations: [(ObjectIdentifier, String)] = []
        let fixture = ThemeSurfaceRenderingFixture(content: AnyView(LanguageLifetimeProbe { identity, locale in
            observations.append((identity, locale))
        }.appLanguage(from: store)), size: CGSize(width: 280, height: 120), colorScheme: .light)
        defer { fixture.close() }
        _ = try await fixture.capture(named: "language-en")
        try await expectEventually { !observations.isEmpty }
        let originalIdentity = try #require(observations.first?.0)
        store.setLanguage(AppInterfaceLanguage(identifier: "zh-Hans"))
        _ = try await fixture.capture(named: "language-zh")
        try await expectEventually { observations.last?.1 == "zh-Hans" }
        #expect(observations.allSatisfy { $0.0 == originalIdentity })
    }
}

@MainActor
private final class LanguageViewLifetime: ObservableObject {}

private struct LanguageLifetimeProbe: View {
    @StateObject private var lifetime = LanguageViewLifetime()
    @Environment(\.locale) private var locale
    let onObserve: (ObjectIdentifier, String) -> Void

    var body: some View {
        Text("General", bundle: AppLocalization.resourceBundle)
            .onAppear { onObserve(ObjectIdentifier(lifetime), locale.identifier) }
            .onChange(of: locale.identifier) { onObserve(ObjectIdentifier(lifetime), locale.identifier) }
    }
}
