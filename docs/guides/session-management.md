# Managing AI coding sessions with JustSessions

[Back to JustSessions](../../README.md) · [Session storage and privacy](session-storage.md)

Use the sidebar to find a conversation, read its preview, and resume it in its original CLI. These instructions cover the controls, notifications, SSH setup, terminal persistence, cleanup, and appearance settings.

## Find any session

- All Claude Code, Codex, Antigravity CLI, Kiro CLI, OpenCode, and Pi sessions in one sidebar, grouped by machine (this Mac, then each SSH host), then by project folder, sorted by recent activity.
- Search projects by name or path, and sessions by title or session ID.
- Filter to sessions from the past seven days, or to one CLI. The filter lists only CLIs that are installed or have sessions.
- Pin projects and sessions to keep them at the top. Rename any session locally without touching the CLI's own title.

## Preview before you resume

- Read a Claude Code, Codex, or Kiro CLI conversation without starting the CLI. Your messages and the agent's replies are shown; runs of tool calls collapse into one expandable row.

## Resume, branch, and start sessions

- Resume a session in its native CLI inside an embedded terminal: double-click it, use **Resume**, or right-click.
- Branch (fork) a Claude Code, Codex, OpenCode, or Pi conversation into a new session. This forks the conversation, not a Git branch.
- Kiro CLI supports a fork at an earlier turn with `/rewind` inside the resumed session. It does not currently expose a direct branch launch flag, so JustSessions keeps its Branch action unavailable. See [Kiro's rewind documentation](https://kiro.dev/docs/cli/reference/slash-commands/#rewind).
- Start a new session in any project folder, on this Mac or an SSH host, with any supported CLI installed on that machine (Claude Code, Codex, and Kiro CLI on SSH hosts). It appears in the sidebar right away.
- Open a plain terminal in a project folder: choose **Terminal** from the project's **+** menu, or right-click the project and choose **New terminal**. It runs your login shell, on this Mac or the project's SSH host. It is not a session: it isn't listed in the sidebar, sends no notifications, and doesn't run in tmux, so closing its tab ends the shell.
- Keep several terminal tabs open. Select a session in the sidebar to read its preview; a session whose CLI is running opens on its terminal instead. Select a terminal tab to return to its CLI without stopping it.
- Tabs group by project, like tab groups in a browser: a new tab opens next to its project's other tabs, behind a label in the project's color. Click the label to collapse the group; a collapsed group keeps only its selected tab in sight and shows how many tabs it hides and the most pressing status among them.
- With tmux 3.3 or later installed, a CLI on this Mac runs inside tmux. Closing its tab with **Keep running**, quitting the app, or installing an update leaves it running. Select the session to reattach, or right-click it and choose **End on this Mac**.
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

## Notifications

JustSessions posts a macOS notification when a Claude Code or Codex session on this Mac finishes its turn, or stops in the middle of one to wait on you, such as at a permission prompt. Click the notification to open the session: its tab, or a new tab that reattaches to its CLI in tmux.

- Sessions running in tmux with no tab open notify too.
- A session whose tab is selected while JustSessions is in front sends none; you already see it.
- macOS asks for permission the first time there is something to notify about.
- Turn either kind off in **Settings > Notifications**. Banners, sounds, and Do Not Disturb follow **System Settings > Notifications**.
- SSH hosts, Antigravity CLI, Kiro CLI, OpenCode, and Pi don't report what their CLI is doing, so they send no notifications.

## SSH hosts

The host must accept `ssh <host>` without a password prompt and have `rsync` plus the CLI you want to run installed. The app reads Claude Code, Codex, and Kiro CLI history from the host's standard session folders.

- Click **Add SSH host…** at the bottom left of the sidebar and enter a host from `~/.ssh/config` or `user@hostname`. Its Claude Code, Codex, and Kiro CLI sessions are listed under its own heading, below this Mac's.
- Resume, branch, start, and delete sessions on the host over SSH, just like on this Mac.
- Refresh updates every host at once. A host that can't be reached shows the error on its heading; the others still list.
- With tmux on the host, a session there keeps running when the connection drops or the tab closes. Select the session to reattach.

## Clean up

- Delete sessions one at a time, in a multi-selection (⌘-click, ⇧-click), or per project, always after a confirmation.
- Projects stay in the sidebar after their last session is deleted, including after restarting the app. Right-click a project and choose **Remove from sidebar** to hide it without deleting its sessions or folder. Starting a new session in that folder brings it back.
- Select several projects with ⌘-click, or select a continuous range with Shift-click, then click **Remove from sidebar** at the bottom of the sidebar or right-click a selected project and choose **Remove … projects from sidebar**. Open terminals keep running. Use a project's arrow to expand or collapse it while keeping the selection.
- Click empty space in the sidebar or press Escape while the sidebar is focused to cancel a project or session batch selection. A single session's conversation stays open.
- Claude Code sessions on this Mac go to the macOS Trash. Codex uses `codex delete --force`, and Kiro CLI uses `kiro-cli chat --delete-session <session-id>`. SSH hosts have no Trash, so deletions there are permanent.
- Sessions with an open terminal tab, or still running in tmux, can't be deleted.

## Appearance

Open **Settings** at the bottom of the sidebar, or press ⌘,.

- **Appearance**: choose **System** to switch between light and dark with your Mac, or keep the app **Light** or **Dark**.
- **Theme**: choose the app's colors: JustSessions, Solarized, Gruvbox, Catppuccin, Tokyo Night, or Rosé Pine. Each theme has light and dark colors, and **Appearance** picks between them. Terminals use the theme's colors too.
- **Terminal**: terminals match the app unless you give them the theme's **Light** or **Dark** colors. The font and size are set here too. Changes apply to open terminals right away.
