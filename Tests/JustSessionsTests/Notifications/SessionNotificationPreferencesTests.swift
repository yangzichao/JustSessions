import Foundation
import Testing
@testable import JustSessions

@MainActor
struct SessionNotificationPreferencesTests {
    @Test func bothMomentsNotifyUntilTurnedOff() {
        let preferences = SessionNotificationPreferences()

        #expect(preferences.allows(.needsInput(reason: nil)))
        #expect(preferences.allows(.finishedTurn))
    }

    @Test func eachChoiceTurnsOffOnlyItsMomentAndSurvivesReopening() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = SessionNotificationSettingsStore(userDefaults: settings.userDefaults)

        store.setNotifiesWhenTurnFinishes(false)

        let reopened = SessionNotificationSettingsStore(userDefaults: settings.userDefaults).preferences
        #expect(reopened.allows(.needsInput(reason: "input needed")))
        #expect(!reopened.allows(.finishedTurn))
    }

    @Test func aMissingOrUnknownSavedValueResetsOnlyThatChoice() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set(
            Data(#"{"notifiesWhenInputNeeded":false,"notifiesWhenTurnFinishes":"sometimes"}"#.utf8),
            forKey: SessionNotificationPreferences.userDefaultsKey
        )

        let preferences = SessionNotificationPreferences.load(from: settings.userDefaults)
        #expect(!preferences.notifiesWhenInputNeeded)
        #expect(preferences.notifiesWhenTurnFinishes)
    }
}
