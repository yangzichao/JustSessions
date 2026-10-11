# Terminal rendering and input

[Back to requirements](../README.md)

## Engine

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| TRM-01 | New tabs open in SwiftTerm by default. Settings → Appearance → Terminal → Engine can choose Ghostty for new tabs. A tab keeps the engine it opened with when it reconnects, moves or is dragged to another window, or starts again; tabs reopened at launch take the engine chosen then. With SwiftTerm chosen, the app behaves as it did before Ghostty was added. | `8d6e97d` | `TerminalEngineStoreTests`, `TerminalEngineReopeningTests`, `TerminalEngineTabMovingTests` |
| TRM-02 | A Ghostty tab keeps every SwiftTerm tab behavior: process lifecycle, tmux pane processes, titles, PTY size; hidden-tab output batching; light and dark reports; Shift-Return in tmux, Page Up and Down; app menu shortcuts; file drop, copy, paste, select all, scrolling, and the right-click menu; splits, groups, and dragging between windows; fonts, colors, contrast, live changes, the Settings preview, and zoom. | `8d6e97d` | `Terminal/Engine/*`, `Terminal/Ghostty/*` |
| TRM-03 | The pinned SwiftTerm fork (1.15.0 with `minimumContrastRatio`) and the pinned libghostty-spm fork (2.2.2026100901 with its search counts) are pinned on purpose; changing either needs the engine measurements rerun. | `64eab47`, `8d6e97d`, `1533250`, `09d84fd` | `TerminalEngineMeasurements` |

## Colors and readability

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| TRM-20 | Terminals use the app theme's colors unless a scheme of their own is chosen: an app theme's, Dracula, or Nord. **Import** copies iTerm2's default profile or an `.itermcolors` file once, only when chosen. Choosing an app theme sets terminal colors back to Match app theme; imported colors stay in the menu. | `b481561`, `932fd8a` | `ITermColorsImportTests`, `TerminalAppearancePreferencesTests` |
| TRM-21 | Terminals match the app's light or dark unless set to Light or Dark; a one-version scheme keeps its version. Changes apply to open terminals at once. | `7439345`, `b481561` | `TerminalAppearanceRenderingTests` |
| TRM-22 | Every preset's terminal text reads at 4.5:1. Terminals darken or lighten text a CLI colored for the other background just enough to reach 4.5:1 (Ghostty uses black or white); block characters such as pixel art keep their colors. | `932fd8a`, `64eab47` | `TerminalColorPresetReadabilityTests`, `TerminalMinimumContrastRenderingTests` |
| TRM-23 | Selected text reads at 4.5:1 on the selection color in every theme, including imported schemes and customized backgrounds. | `7ddb6d8`, `ab06a47` | `TerminalMinimumContrastRenderingTests` |
| TRM-24 | Each ANSI color stands at least 1.2:1 apart from the background, so a CLI filling cells with an ANSI color equal to the background still shows them. Colors already that far apart are unchanged. | `b55bfac` | `DistinguishableANSIColorsTests` |
| TRM-25 | A theme change reaches CLIs that follow it: the tab answers `CSI ? 996 n` and sends a report on every color change while subscribed (`CSI ? 2031 h`), without moving the scroll position or selection. On SSH hosts with tmux before 3.6, Claude Code is made to redraw after a light/dark switch. | `d14311d`, `8307649` | `TerminalThemeChangeInTmuxTests`, `TerminalThemeReportingTests`, `UnheardLightDarkChangeTests` |
| TRM-26 | Tabs on SSH hosts set `COLORTERM=truecolor` for the CLI and tmux. | `a049d60` | `TerminalColorEnvironmentTests` |

## Fonts and zoom

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| TRM-40 | The font picker lists System Monospaced and every installed monospaced family, read off the main thread. A chosen family that is later removed shows as not installed while terminals use System Monospaced. | `6cd0a7e` | `TerminalFontFamilyTests` |
| TRM-41 | The bundled Symbols Nerd Font Mono is a fallback for Private Use Area glyphs with any font except System Monospaced in SwiftTerm, which stays exactly the system font. Its license ships with the app. | `6cd0a7e`, `38ee73b` | `TerminalFontFamilyTests` |
| TRM-42 | View → Zoom In (⌘+ or ⌘=), Zoom Out (⌘−), and Actual Size (⌘0) size every terminal's font (10 to 24 points, default 13) while a tab shows, and the reader's text otherwise. They work while a sheet or popover of the window is key. | `19b4af9`, `735a8fb` | `TextZoomTargetRegistryTests`, `TextZoomStepTests` |
| TRM-43 | The Settings terminal preview keeps a fixed height; a bigger font shows fewer lines. | `ad34ae9` | Manual |

## Input

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| TRM-60 | The CLI always receives mouse input; there is no toggle for it. Shift-drag selects text and ⌘C copies it; in a tmux tab a plain drag copies on release. | `0edb74d`, `715a0c2`, `9dd8461` | `TerminalInteractionTests` |
| TRM-61 | Shift-Return reaches a CLI in tmux as `CSI 13;2u`. | `b6dfd68` | `ThisMacTmuxShiftReturnTests` |
| TRM-62 | Right-clicking a terminal selects its pane's tab, then offers Copy, Paste, Select All, and the tab's items (Rename, Copy and Export conversation, split items, End session or Close terminal). No AutoFill items appear. | `ca8bc76`, `c498934` | `TerminalRightClickTests`, `TerminalContextMenuItemsTests` |
| TRM-63 | Dropping files from Finder on a tab types each path, backslash-escaped, as its own bracketed paste (a shell gets them separated by spaces). The pane dropped on takes the keyboard. A tab on an SSH host types the paths of copies on the host (TRM-64). | `8640e32` | `TerminalFileDropPasteTests`, `TerminalFileDropAcceptanceTests` |
| TRM-64 | Files dropped on a tab on an SSH host are copied first, one at a time, over the connection the app's background commands use, each into a new folder only its owner can open in `~/.cache/justsessions/dropped-files` on the host, under its own name. Their host paths are typed once every file is there. Files dropped during a copy join it. A copy taking over half a second shows its progress and Cancel over the pane's top-trailing corner, without resizing the terminal. A failure says why there and types nothing, as do Cancel, closing the tab, and its CLI ending. A drop with a folder is refused. Each copy first removes copies more than a week old. | `40a2696` | `TerminalSSHFileDropTests`, `TerminalSSHFileDropTabTests`, `RemoteDroppedFileCopierTests`, `RemoteDroppedFileCopyScriptTests` |
| TRM-65 | ⌘F in a plain terminal, or a CLI tab not yet linked to its session, opens the app's find bar over the terminal's top trailing corner, with either engine, without resizing the terminal. Typing selects the newest match, ignoring case. Return or ⌘G goes to older matches and Shift-Return or ⇧⌘G to newer ones, wrapping at both ends; Escape closes the bar. Return and Escape reach the terminal's program unless the find field has the keyboard. Closing gives the keyboard back to the terminal and keeps the text for the next ⌘F. The bar shows the selected match's number and the count with either engine. A SwiftTerm tab keeps 10,000 lines of scrollback; a Ghostty tab's count rises while Ghostty reads its scrollback. In a tab linked to a session, ⌘F opens its conversation in a reading window with Find showing, without changing the selected tab. | `9b8d882`, `09d84fd` | `TerminalFindStateTests`, `TerminalFindShortcutsTests`, `TerminalFindBarFocusTests`, `SwiftTermTerminalFindTests`, `GhosttyTerminalFindTests`, `GhosttyFindProgressTests`, `TerminalFindTargetTests`, `SessionReadingWindowTests` |
