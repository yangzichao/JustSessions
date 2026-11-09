# tmux, closing, and reopening tabs

[Back to requirements](../README.md)

## Keep running

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| TMX-01 | The app bundles tmux, so CLIs on this Mac keep running without a separate install. They run in the app's own server (`tmux -L justsessions`, no configuration file). Direct `swift run` builds use an installed tmux 3.3 or later; without tmux, a CLI runs directly. | `b6dfd68`, `c3ab5fc` | `BundledTmuxRuntimeTests`, `ThisMacTmuxServerTests` |
| TMX-02 | Closing a tab with **Keep running**, quitting, or a Sparkle update leaves its CLI running. Selecting the session reattaches; **End on this Mac** stops it. | `b6dfd68`, `f1e5820` | `ThisMacTmuxKeepAliveTests`, `ThisMacTmuxStoreTests` |
| TMX-03 | tmux sessions have no prefix key, so every key, Control-B included, reaches the CLI. An SSH host can opt in to its own prefix (prefix and prefix2 unset) from its ⋯ menu; the choice is saved per host, applied to its running sessions at once, and remakes reopened tabs still waiting. This Mac is unaffected. | `b6dfd68`, `38fd6c0` | `RemoteTmuxPrefixChoiceTests`, `RemoteTmuxPrefixKeysTests` |
| TMX-04 | Renames and kills of a host's tmux sessions run in order on one queue per host, so an End right after a rename never misses. | `59e2033` | `RemoteTmuxCommandOrderTests` |
| TMX-05 | A CLI that ended in tmux stops counting as running within about a second; dead panes are never counted. | `8fa46b7`, `b2747b3` | `DetachedCLIActivityTmuxTests`, `ThisMacTmuxDeadPaneTests` |
| TMX-06 | On this Mac, a Kiro CLI left running in tmux under a tab's temporary name that no tab shows, as by a Kiro tab closed before it linked to its session (every Kiro tab before v1.2.20, DSC-08), takes its session's own name once Kiro's lock on that session (`<id>.lock` beside a V2 session, `.lock` in a V3 session's folder) names a process under its pane. The session then counts as running in tmux (TMX-02): selecting it reattaches instead of starting a second CLI on it, and **Close and delete session…** ends it first (DEL-12). This is checked after each refresh of this Mac, off the main thread, and reads the locks and the process table only while such a tmux session runs. | Bug report, 24 October 2026 | `LostKiroCLIsTests`, `LostKiroCLIRecoveryTests` |

## Ending and closing

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| TMX-20 | Closing a tab whose CLI can keep running asks **Keep running** or **End session**. Return picks Keep running (End session or Close terminal when it can't keep running); Escape cancels. It is an alert so Return works. | `fefce02`, `a4101ee` | `TerminalTabCloseConfirmationTests` |
| TMX-21 | **Don't ask again** remembers the choice, separately for CLI tabs and plain terminals. A CLI tab's choice is saved for its host only, and the checkbox names it (**Don't ask again on devbox**); the plain terminal choice covers every host. Settings → General → Tabs shows each host's CLI tab choice, This Mac first, and the plain terminal choice, and can set each back to Ask each time. Removing an SSH host forgets its choice. Closing several tabs at once reads each tab's own host's choice. | `e5f95f4`, `2ff2669`, `9aabe60` | `TabCloseChoiceSettingsStoreTests`, `PlainTerminalCloseChoiceSettingsStoreTests`, `SeveralTabsClosingQuestionTests`, `ClosingSeveralTabsStoreTests` |
| TMX-22 | Closing a tab sends SIGHUP first, so an interactive shell ends and a tmux client detaches, and the process is reaped, leaving no zombies. A closed tab's terminal is freed once its window's views go. | `cc64424`, `8d6e97d` | `ClosedTabProcessTests`, `ClosedTabReleaseTests` |
| TMX-23 | A CLI that fails at once keeps what it printed in its tab (`remain-on-exit failed`, without tmux's "Pane is dead" line), and the ended bar shows the CLI's own exit status, never tmux's or the raw wait status. | `b2747b3` | `ThisMacTmuxFailedCLITests` |
| TMX-24 | An ended tab stays open showing how it ended. Resuming its session starts it again in that tab, keeping its place, split, and selection; a dead tmux session is ended first. Overlapping Resume requests in any window wait for that cleanup, so an old cleanup cannot kill the new CLI. Branch still opens its own tab. | `cd21fc3`, `b2747b3` | `RunningCLISelectionTests`, `FailedCLIRestartOwnershipTests` |
| TMX-25 | A session's open tab menu offers **Close terminal…** with the same Keep running / End session choice as the tab's ×. | `5b35d08` | Manual |
| TMX-26 | A session's tab menu, in the tab bar, Open tabs, or its terminal, follows **Close Tab…** with **Close and end session** while its CLI runs, in tmux or with the tab, and **Close and delete session…** once the tab is linked to its session. Close and end session stops the CLI without asking, as End session does from the session's row; Close and delete session… opens the deletion dialog (DEL-12). A tab whose session is deleted when it closes (DSC-56) offers **Keep session** and **Close and delete session** in their place. | `2cbbbbc`, `15cf5192` | `TerminalContextMenuItemsTests`, `TerminalContextMenuActionTests`, `ThisMacTmuxCloseAndEndSessionTests` |

## Reopening tabs

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| TMX-40 | With **Reopen tabs** on (Settings → General, default on), the tabs that were open come back at launch in their saved order across hosts, with the selected one marked. | `3c634a3` | `TabReopeningStoreTests`, `TabReopeningSettingsStoreTests` |
| TMX-41 | Open tabs are saved as they change, including newly linked sessions, so recovery doesn't depend on a normal quit. | `b4215de` | `LiveTabPersistenceTests`, `OpenTabPersistenceTests` |
| TMX-42 | A CLI still running in tmux reattaches at once. Any other reopened tab waits until selected, shows a dotted status, counts as not running, and closes without the keep-running prompt. | `3c634a3` | `WaitingToBeShownTabTests` |
| TMX-43 | Tabs waiting for a host or CLI that isn't available yet stay saved until they can reopen. An SSH tab is given up only after its host's last tool is listed. | `8a98872`, `ec75564` | `PendingTabReopeningTests` |
| TMX-44 | Closing the last window keeps its tabs for the next window or launch; closing one of several windows discards that window's tabs. | `e40d9e6` | `TabReopeningStoreTests` |
| TMX-45 | A session open in another window is skipped when tabs reopen. | `0f3fd89` | `SessionTabAcrossWindowsTests` |
| TMX-46 | **File → Reopen Closed Tab** (⇧⌘T), as in Chrome, brings back the latest tab closed in its window, at its place in the tab bar and selected; each press reopens the one closed before. A session tab resumes its session, reattaching when tmux kept its CLI running and connecting a disconnected host as resuming does; a plain terminal opens a new shell in its folder. A session with a tab again, in any window, shows that tab. A closed tab whose session is gone, whose folder is missing, or whose host was removed is passed over. Each window keeps its latest 25 while it is open. Tabs closed to delete their session (DEL-12, DSC-56), moved to another window (TAB-62), or closed by disconnecting their host are not kept, nor is a New session tab not linked yet. The session's archive stays as it is (DEL-33). | Feature request, 24 October 2026 | `ReopeningClosedTabsTests`, `RecentlyClosedTabsTests`, `TabsGoneWithoutClosingTests` |
