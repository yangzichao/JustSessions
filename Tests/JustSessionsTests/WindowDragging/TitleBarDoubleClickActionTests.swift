import Testing
@testable import JustSessions

/// Double-clicking the tab bar's empty space does what double-clicking a title bar does, as chosen in System Settings.
struct TitleBarDoubleClickActionTests {
    @Test func aDoubleClickDoesWhatSystemSettingsChose() {
        #expect(TitleBarDoubleClickAction(actionSetting: nil, minimizesSetting: false) == .zoom)
        #expect(TitleBarDoubleClickAction(actionSetting: nil, minimizesSetting: true) == .minimize)
        #expect(TitleBarDoubleClickAction(actionSetting: "Maximize", minimizesSetting: true) == .zoom)
        #expect(TitleBarDoubleClickAction(actionSetting: "Fill", minimizesSetting: false) == .zoom)
        #expect(TitleBarDoubleClickAction(actionSetting: "Minimize", minimizesSetting: false) == .minimize)
        #expect(TitleBarDoubleClickAction(actionSetting: "None", minimizesSetting: true) == .nothing)
    }
}
