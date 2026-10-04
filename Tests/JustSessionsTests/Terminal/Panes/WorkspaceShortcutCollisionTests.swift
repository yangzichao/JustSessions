import Testing
@testable import JustSessions

/// Mirrors the shortcuts the app registers, so a new binding that collides with an existing one fails here
/// before it ships. Update this list together with the `Commands` and shortcut views it describes.
struct WorkspaceShortcutCollisionTests {
    @Test func everyRegisteredShortcutIsUnique() {
        let shortcuts: [(key: String, modifiers: String, purpose: String)] = [
            // WorkspaceTabCommands
            ("n", "⌘", "New Session"),
            ("t", "⌘", "New Tab"),
            ("n", "⇧⌘", "New Window"),
            ("w", "⌘", "Close Tab / Close Window"),
            ("[", "⇧⌘", "Previous Tab"),
            ("]", "⇧⌘", "Next Tab"),
            ("d", "⌘", "Split Right"),
            ("d", "⇧⌘", "Split Down"),
            ("w", "⌃⌘", "Close Pane"),
            ("1…9", "⌘", "Tab by number"),
            // SidebarToggleCommands
            ("s", "⌃⌘", "Toggle sidebar"),
            // Transcript search, scoped to the visible reader
            ("f", "⌘", "Find in conversation"),
            ("g", "⌘", "Next match"),
            ("g", "⇧⌘", "Previous match"),
        ]

        let combos = shortcuts.map { "\($0.modifiers)\($0.key)" }
        #expect(Set(combos).count == combos.count, "Colliding shortcuts: \(combos)")
    }
}
