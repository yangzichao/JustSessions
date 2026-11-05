import AppKit
import Testing
@testable import JustSessions

/// The New session items an AppKit menu lists, such as a terminal's Split right and Split down: as the SwiftUI menus
/// list them, one per CLI found, with its icon, or a line saying none was found.
@MainActor
struct NewSessionProviderMenuItemsTests {
    @Test func eachCLIFoundIsAnItemWithItsIconThatStartsIt() throws {
        let providers = Array(ConversationProvider.allCases.prefix(2))
        var started: [ConversationProvider] = []

        let items = NewSessionProviderMenuItems.appKitItems(
            providers: providers,
            host: .thisMac,
            language: AppLocalization.developmentLanguage,
            isEnabled: true
        ) { started.append($0) }

        #expect(items.map(\.title) == providers.map(\.rawValue))
        #expect(items.allSatisfy { $0.isEnabled && $0.image != nil })
        let last = try #require(items.last)
        _ = (last.target as AnyObject).perform(last.action, with: last)
        #expect(started == [providers[1]])
    }

    @Test func itemsAreDisabledWhileNoNewTabCanStart() {
        let items = NewSessionProviderMenuItems.appKitItems(
            providers: [ConversationProvider.allCases[0]],
            host: .thisMac,
            language: AppLocalization.developmentLanguage,
            isEnabled: false
        ) { _ in }

        #expect(items.map(\.isEnabled) == [false])
    }

    @Test func aHostWithNoCLISaysSoInADisabledItem() {
        let items = NewSessionProviderMenuItems.appKitItems(
            providers: [],
            host: .thisMac,
            language: AppLocalization.developmentLanguage,
            isEnabled: true
        ) { _ in }

        #expect(items.map(\.title) == [NewSessionProviderAvailability.noCLIFoundMessage(on: .thisMac)])
        #expect(items.map(\.isEnabled) == [false])
    }
}
