# Managing AI coding sessions with JustSessions

[Back to JustSessions](../../README.md) · [Session storage and privacy](session-storage.md)

Use the sidebar to find a conversation, read its preview, and resume it in its original CLI. These instructions cover the controls, SSH setup, terminal persistence, cleanup, and appearance settings.

## Find any session

- All Claude Code, Codex, and Antigravity CLI sessions in one sidebar, grouped by machine (this Mac, then each SSH host), then by project folder, sorted by recent activity.
- Search projects by name or path, and sessions by title or session ID.
- Filter to sessions from the past seven days, or to one CLI.
- Pin projects and sessions to keep them at the top. Rename any session locally without touching the CLI's own title.

## Preview before you resume

- Read a Claude Code or Codex conversation without starting the CLI. Your messages and the agent's replies are shown; runs of tool calls collapse into one expandable row.

## Resume, branch, and start sessions

- Resume a session in its native CLI inside an embedded terminal: double-click it, use **Resume**, or right-click.
- Branch (fork) a Claude Code or Codex conversation into a new session. This forks the conversation, not a Git branch.
- Start a new session in any project folder, on this Mac or an SSH host, with any CLI supported on that machine (Claude Code and Codex on SSH hosts). It appears in the sidebar right away.
- Keep several terminal tabs open. Select a session in the sidebar to read its preview, or select a terminal tab to return to its CLI without stopping it.
- With tmux 3.3 or later installed, a CLI on this Mac runs inside tmux. Closing its tab with **Keep running**, quitting the app, or installing an update leaves it running. Resume the session to reattach, or right-click it and choose **End on this Mac**.
- Pick up names set with `/rename` in Claude Code within about a second.
- See what each CLI is doing on its sidebar row, its project, and its tab: a turning arc while it works, an amber mark while it waits on your answer, a green dot while it waits for your next prompt, and a hollow circle once it ended in a tab still open. A session with no running CLI shows how long ago it was active instead. Claude Code and Codex on this Mac tell what they are doing, also while they run in tmux with no tab open; elsewhere the green dot only says the CLI runs.

## SSH hosts

The host must accept `ssh <host>` without a password prompt and have `rsync` plus the CLI you want to run installed. The app reads Claude Code and Codex history from the host's standard session folders.

- Click **Add SSH host…** at the bottom left of the sidebar and enter a host from `~/.ssh/config` or `user@hostname`. Its Claude Code and Codex sessions are listed under its own heading, below this Mac's.
- Resume, branch, start, and delete sessions on the host over SSH, just like on this Mac.
- Refresh updates every host at once. A host that can't be reached shows the error on its heading; the others still list.
- With tmux on the host, a session there keeps running when the connection drops or the tab closes. Resume to reattach.

## Clean up

- Delete sessions one at a time, in a multi-selection (⌘-click, ⇧-click), or per project, always after a confirmation.
- Projects stay in the sidebar after their last session is deleted, including after restarting the app. Right-click a project and choose **Remove from sidebar** to hide it without deleting its sessions or folder. Starting a new session in that folder brings it back.
- Claude Code sessions on this Mac go to the macOS Trash. Codex uses `codex delete --force`. SSH hosts have no Trash, so deletions there are permanent.
- Sessions with an open terminal tab, or still running in tmux, can't be deleted.

## Appearance

Open **Settings** at the bottom of the sidebar, or press ⌘,.

- **Appearance**: choose **System** to switch between light and dark with your Mac, or keep the app **Light** or **Dark**.
- **Terminal**: terminals match the app unless you give them **Light** or **Dark** colors of their own. The font and size are set here too. Changes apply to open terminals right away.
