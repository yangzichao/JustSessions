/// One terminal's light and dark theme reports: the current theme when a program asks, and every change to the
/// terminal's colors while it subscribes. tmux reads the terminal's colors again on each report, so a CLI in tmux that
/// asks for the background after a theme change gets the new one instead of the one tmux saw when it attached.
struct TerminalThemeReporting {
    private var scanner = TerminalThemeReportRequestScanner()
    private(set) var isSubscribed = false
    /// Set for a change no program subscribed to; see `ConversationStore+RemoteTmuxColors`. The report then follows
    /// the terminal's answer to the next background query, as tmux makes when its client attaches again.
    private(set) var reportsAfterNextBackgroundQuery = false

    /// `CSI ? 997 ; 1 n` for a dark background, `CSI ? 997 ; 2 n` for a light one.
    static func report(isDark: Bool) -> String {
        "\u{1B}[?997;\(isDark ? 1 : 2)n"
    }

    /// The reports that answer the requests in `output`, in order. They go out after the terminal has read `output`,
    /// so a report owed after a background query follows the terminal's own answer to it.
    mutating func reports(answering output: ArraySlice<UInt8>, isDark: Bool) -> [String] {
        scanner.scan(output).compactMap { request in
            switch request {
            case .subscribe:
                isSubscribed = true
                return nil
            case .unsubscribe:
                isSubscribed = false
                return nil
            case .currentTheme:
                return Self.report(isDark: isDark)
            case .backgroundColor:
                guard reportsAfterNextBackgroundQuery else { return nil }
                reportsAfterNextBackgroundQuery = false
                return Self.report(isDark: isDark)
            }
        }
    }

    /// The report for colors the terminal just took on, while a program subscribes.
    func reportAfterColorChange(isDark: Bool) -> String? {
        isSubscribed ? Self.report(isDark: isDark) : nil
    }

    mutating func reportAfterNextBackgroundQuery() {
        reportsAfterNextBackgroundQuery = true
    }

    mutating func cancelReportAfterNextBackgroundQuery() {
        reportsAfterNextBackgroundQuery = false
    }
}
