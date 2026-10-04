# Managing AI coding sessions with JustSessions

[Back to JustSessions](../../README.md) · [Session storage and privacy](session-storage.md)

Use the sidebar to find a conversation, read its preview, and resume it in its original CLI. These instructions cover the controls, notifications, SSH setup, terminal persistence, cleanup, and appearance settings.

## Find any session

- All Claude Code, Codex, Antigravity CLI, Kiro CLI, OpenCode, and Pi sessions in one sidebar, grouped by machine (this Mac, then each SSH host), then by project folder, sorted by recent activity.
- Search projects by name or path, and sessions by title or session ID.
- Filter to sessions from the past seven days, or to one CLI. The filter lists only CLIs that are installed or have sessions.
- Pin projects and sessions to keep them at the top. Rename any session locally without touching the CLI's own title.
- Hide the sidebar to give the terminal or preview the whole window: click the sidebar button next to the window's close, minimize, and zoom buttons, choose **View → Hide Sidebar**, or press **⌃⌘S**. Each window keeps its own choice, and the sidebar comes back with the same projects expanded.

## Preview before you resume

- Read a Claude Code, Codex, Antigravity, Kiro CLI, OpenCode, or Pi conversation without starting the CLI. Your messages and the agent's replies are shown; runs of tool calls collapse into one expandable row. Images you attached, and images a tool returned such as screenshots, are shown in place for Claude Code, Codex, and Pi, scaled to the reading column.
- The new-window button at the end of the preview's reading toolbar opens a separate, read-only window at your current position without changing the selected terminal. Opening it again brings the existing window for that session forward; different sessions can have separate reading windows.
- Large conversations load in pages, starting with the latest messages or your saved reading position. Nearby history loads automatically as the viewport approaches either end, including while scrolling inside a long message or after restoring a position near an edge. **Load earlier messages** / **Load later messages** remain available for manual loading and retries. The reader keeps up to three pages and reloads distant pages when you return to them; loading history preserves your position within the message, even if you keep scrolling during the load. The first/latest buttons can jump beyond the currently loaded pages.
- Use **A− / A+** to adjust text size from 12 to 22 points. The width button switches between a readable column and the full window width, and the preview and every reading window share the choice, which is remembered after you quit. The up/down buttons go to the first or latest available message. Markdown formatting, tables, and code blocks remain readable; wide tables and code blocks scroll horizontally, and code blocks have a **Copy** button.
- Switching sessions restores your reading position while the workspace window stays open, including a position within a long message. Reading positions are not saved across app restarts. A separate reading window keeps its own position until it closes.
- Press **⌘F**, or click the magnifying glass in the reading toolbar, to search the displayed conversation. Matches ignore case and accents and include message text, code, table cells, and tool summaries. Use **Return / ⌘G** for the next match, **⇧Return / ⇧⌘G** for the previous one, or the arrow buttons; navigation wraps at either end. **Escape** closes search. The selected match is highlighted and brought into view, and a matching tool summary opens its disclosure. Each preview or reading window has its own search. Search covers the currently loaded pages; unloaded pages and text beyond a message's preview limit are not searched. Automatic page loading pauses while Find is open; the page buttons remain available. The shortcuts apply to the reader while it is visible and leave active CLI terminals alone.

## Resume, branch, and start sessions

- Resume a session in its native CLI inside an embedded terminal: double-click it, use **Resume**, or right-click.
- Branch (fork) a Claude Code, Codex, OpenCode, or Pi conversation into a new session. This forks the conversation, not a Git branch.
- Kiro CLI supports a fork at an earlier turn with `/rewind` inside the resumed session. It does not currently expose a direct branch launch flag, so JustSessions keeps its Branch action unavailable. See [Kiro's rewind documentation](https://kiro.dev/docs/cli/reference/slash-commands/#rewind).
- Start a new session in any project folder, on this Mac or an SSH host, with any supported CLI installed on that machine. It appears in the sidebar right away.
- Open a plain terminal in a project folder: choose **Terminal** from the project's **+** menu, or right-click the project and choose **New terminal**. It runs your login shell, on this Mac or the project's SSH host. It is not a session: it isn't listed in the sidebar, sends no notifications, and doesn't run in tmux, so closing its tab ends the shell.
- Keep several terminal tabs open. Select a session in the sidebar to read its preview; a session whose CLI is running opens on its terminal instead. Select a terminal tab to return to its CLI without stopping it.
- Tabs group by project, like tab groups in a browser: a new tab opens next to its project's other tabs, behind a label in the project's color. Click the label to collapse or expand the group. A collapsed group shows only its label, with how many tabs it hides and the most pressing status among them. Collapsing the group of the tab you're on switches to the nearest tab still in sight; selecting a hidden tab, by shortcut or from the sidebar, expands its group.
- The app includes tmux for CLI sessions on this Mac. Direct `swift run` builds use an installed tmux 3.3 or later. Closing a tab with **Keep running**, quitting the app, or installing an update leaves its CLI running. Select the session to reattach, or right-click it and choose **End on this Mac**.
- Pick up names set with `/rename` in Claude Code within about a second.
- See what each CLI is doing on its sidebar row, its project, and its tab: a turning arc while it works, an amber mark while it waits on your answer, a green dot while it waits for your next prompt, and a hollow circle once it ended in a tab still open. A session with no running CLI shows how long ago it was active instead. Claude Code and Codex on this Mac tell what they are doing, also while they run in tmux with no tab open; elsewhere the green dot only says the CLI runs.

## Tab keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘T or ⌘N | Open the new session sheet using the current tab's host, CLI, and project folder. |
| ⌘⇧N | Open another workspace window. |
| ⌘W | Close the selected terminal tab, with the same **Keep running / End session** confirmation as its close button. |
| ⌘⇧] or Ctrl+Tab | Select the next terminal tab, wrapping to the first. |
| ⌘⇧[ or Ctrl+Shift+Tab | Select the previous terminal tab, wrapping to the last. |
| ⌘1 through ⌘8 | Select a terminal tab by its position. |
| ⌘9 | Select the last terminal tab. |

These shortcuts work while the CLI has keyboard focus. From a session preview, next/previous selects the first/last open terminal tab. ⌘W stays disabled in a preview while terminal tabs are open; with no tabs, it closes the window. The **File** and **Tabs** menus list the commands.

To copy terminal text, hold Shift while dragging to select it, then press ⌘C. In a tmux tab, a plain drag also copies when you let go.

## Notifications

JustSessions posts a macOS notification when a Claude Code or Codex session on this Mac finishes its turn, or stops in the middle of one to wait on you, such as at a permission prompt. Click the notification to open the session: its tab, or a new tab that reattaches to its CLI in tmux.

- Sessions running in tmux with no tab open notify too.
- A session whose tab is selected while JustSessions is in front sends none; you already see it.
- macOS asks for permission the first time there is something to notify about.
- Turn either kind off in **Settings > Notifications**. Banners, sounds, and Do Not Disturb follow **System Settings > Notifications**.
- SSH hosts, Antigravity CLI, Kiro CLI, OpenCode, and Pi don't report what their CLI is doing, so they send no notifications.

## SSH hosts

The host must accept `ssh <host>` without a password prompt and have `rsync` plus the CLI you want to run installed. Antigravity and OpenCode hosts also need `python3`; deleting an Antigravity session there needs `lsof`. The app reads Claude Code, Codex, Antigravity, Kiro CLI, and Pi history from the host's standard session folders, and OpenCode history from the database the host's login shell points OpenCode to. For Pi that is `~/.pi/agent/sessions`; a `PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`, or `sessionDir` setting on the host is not followed.

- Click **Add SSH host…** at the bottom left of the sidebar and enter a host from `~/.ssh/config` or `user@hostname`. Its Claude Code, Codex, Antigravity, Kiro CLI, OpenCode, and Pi sessions are listed under its own heading, below this Mac's.
- Resume, branch, start, and delete sessions on the host over SSH, just like on this Mac. SSH hosts have no Trash, so deleting a session there is permanent; for Pi, the folder beside the session file goes too.
- Refresh updates every host at once. A host that can't be reached shows the error on its heading; the others still list.
- Install **tmux on the remote host** so a session there keeps running when the connection drops or the tab closes. The app's bundled tmux is only for this Mac. Run `tmux -V` on the host to check installation, then select the session to reattach.

## Clean up

- Delete sessions one at a time, in a multi-selection (⌘-click, ⇧-click), or per project, always after a confirmation.
- The bottom of the sidebar shows the progress of deleting several sessions, for example **Deleting 37 of 140…**. Click **Cancel** to stop after the session being deleted; the rest stay listed and are not reported as failures. A session on an SSH host can take up to a minute to finish or time out, so stopping can take that long. Refreshing a host waits until a deletion from it ends, and sessions can't be deleted while their host is refreshing.
- If an SSH host can't be reached or doesn't respond within a minute during a deletion, the app skips its remaining sessions and keep them listed, and still delete the other sessions. A connection that stops responding, for example after the Mac sleeps, is given up after about 30 seconds.
- When sessions can't be deleted, the app says how many were deleted, why the others weren't, and what to do, for example to check your network or VPN, or that `ssh <host>` works in Terminal without a password. A host's connection problem is named once instead of for each session. If the cause may pass, such as a lost connection, click **Try Again** to delete the sessions still listed on the hosts that had it; the alert says which. Sessions that failed for another reason, or that Cancel left, are not retried. If a deletion runs, or a host the sessions are on is being refreshed, the retry starts when that ends.
- A session that is already gone, for example because it was deleted just before the connection dropped, counts as deleted: it leaves the list without an error.
- Projects stay in the sidebar after their last session is deleted, including after restarting the app. Right-click a project and choose **Archive project** to hide it without deleting its sessions or folder. **Archived projects (…)** at the bottom of the sidebar, shown while any are archived, lists them with a **Restore** button each; starting a new session in an archived folder also restores it.
- Select several projects with ⌘-click, or select a continuous range with Shift-click, then click **Archive** at the bottom of the sidebar or right-click a selected project and choose **Archive … projects**. Open terminals keep running. Use a project's arrow to expand or collapse it while keeping the selection.
- Click empty space in the sidebar or press Escape while the sidebar is focused to cancel a project or session batch selection. A single session's conversation stays open.
- Claude Code, Antigravity, and Pi sessions on this Mac go to the macOS Trash; a Pi session's folder beside its file goes too, if there is one. Codex uses `codex delete --force`, Kiro CLI uses `kiro-cli chat --delete-session <session-id>`, and OpenCode uses `opencode session delete <session-id>`, which also deletes the session's subagent sessions. SSH hosts have no Trash, so deletions there are permanent.
- Sessions with an open terminal tab, or still running in tmux, can't be deleted.

## Appearance

Open **Settings** at the bottom of the sidebar, or press ⌘,.

- **General > Interface language**: **Follow System** by default, or choose **English** or **Chinese**. Switching updates the interface in place and preserves running terminal tabs. System languages without a matching translation fall back to English.

- **Appearance**: choose **System** to switch between light and dark with your Mac, or keep the app **Light** or **Dark**.
- **Theme**: choose the app's colors: JustSessions, Solarized, Gruvbox, Catppuccin, Tokyo Night, or Rosé Pine. Each theme has light and dark colors, and **Appearance** picks between them. Terminals use the theme's colors too.
- **Terminal > Colors**: terminals use the app theme's colors unless you pick a color scheme of their own: one of the app themes, Dracula, Nord, One Half, or GitHub. **Import** copies the colors of iTerm2's default profile, or of an iTerm2 color preset (`.itermcolors`) file. JustSessions reads iTerm2's settings only when you choose that, and never again after.
- **Terminal > Appearance**: terminals match the app unless you give them the **Light** or **Dark** version of their colors. A scheme with only one version, such as Dracula or Nord, keeps it. The font and size are set here too. Changes apply to open terminals right away.
