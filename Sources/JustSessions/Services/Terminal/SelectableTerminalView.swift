import AppKit
import Combine
import SwiftTerm

/// Keeps the embedded CLI terminal usable as a native text surface.
final class SelectableTerminalView: LocalProcessTerminalView {
    var onSelectionChanged: ((Bool) -> Void)?
    /// For a tab whose CLI runs in tmux on this Mac. SwiftTerm tells Shift-Return from Return only once the CLI
    /// turns on the kitty keyboard protocol, which tmux never does with the tab. So the tab sends Shift-Return as
    /// CSI u itself, and tmux hands it to the CLI unchanged; see `ThisMacTmuxServer.globalOptions`.
    var sendsShiftReturnAsCSIu = false

    private var appearancePreferences = TerminalAppearancePreferences()
    private var theme = AppTheme.justSessions
    private var appearanceSubscription: AnyCancellable?

    override convenience init(frame: CGRect) {
        self.init(frame: frame, appearanceStore: .shared, themeStore: .shared)
    }

    init(frame: CGRect, appearanceStore: TerminalAppearanceStore, themeStore: AppThemeStore) {
        super.init(frame: frame)
        observeAppearance(in: appearanceStore, themeStore: themeStore)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeAppearance(in: .shared, themeStore: .shared)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        TerminalAppearanceStyling.apply(appearancePreferences, theme: theme, to: self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    /// SwiftTerm's `keyDown` hands Return here; while an input method composes text, Return belongs to it.
    override func interpretKeyEvents(_ eventArray: [NSEvent]) {
        if sendsShiftReturnAsCSIu, terminal.keyboardEnhancementFlags.isEmpty, !hasMarkedText(),
           eventArray.count == 1, let event = eventArray.first, ShiftReturnKey.matches(event) {
            send(txt: ShiftReturnKey.csiUSequence)
            return
        }
        super.interpretKeyEvents(eventArray)
    }

    override func selectionChanged(source: Terminal) {
        super.selectionChanged(source: source)
        onSelectionChanged?(selectionActive)
    }

    private func observeAppearance(in store: TerminalAppearanceStore, themeStore: AppThemeStore) {
        appearanceSubscription = store.$preferences.combineLatest(themeStore.$theme).sink { [weak self] preferences, theme in
            guard let self else { return }
            appearancePreferences = preferences
            self.theme = theme
            appearance = preferences.mode.nativeAppearance
            TerminalAppearanceStyling.apply(preferences, theme: theme, to: self)
        }
    }
}
