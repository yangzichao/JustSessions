# Find and resume AI coding sessions on macOS

[Project home](../../README.md) · [Documentation](../README.md) · [Online quick guide](https://yangzichao.github.io/JustSessions/guide.html)

JustSessions reads your existing CLI history and resumes sessions in their original project folders. It is free, open source, and requires no JustSessions account.

## Install

You need **macOS 14 Sonoma or later on Apple Silicon**, plus at least one installed CLI with its usual provider authentication.

| CLI | Executable |
| --- | --- |
| Claude Code | `claude` |
| OpenAI Codex CLI | `codex` |
| Google Antigravity CLI | `agy` |
| Kiro CLI | `kiro-cli` |
| OpenCode | `opencode` |
| Pi | `pi` |

1. Download the signed, notarized [JustSessions.dmg](https://github.com/yangzichao/JustSessions/releases/latest/download/JustSessions.dmg).
2. Open the disk image and drag **JustSessions** into **Applications**.
3. Launch the app. Existing local sessions appear under **This Mac**, grouped by project.

On first launch, a short tour points out your sessions, **New session**, and SSH hosts beside the controls themselves. After that, tips show the first time you need them: reading a session points out **Resume** and find, reading another points out its right-click menu and search, and your first tabs point out tab groups, hiding the sidebar, **Keep running**, **Open tabs**, and split view. Each shows once; skip any of them. To see the tour again, choose **Help → Take the Tour**, or **Take the tour** in **Settings → Help**; the tips then show again too, the next time you reach each part.

Sparkle delivers subsequent app updates. Your CLI provider's plans and charges still apply.

## Resume your first session

1. Choose **Projects** in the sidebar, then search a project name or path, session title, or session ID.
2. Select a supported session to read its conversation preview.
3. Double-click a session or choose **Resume** to open its CLI in the original working directory.

Choose **Open tabs** to switch between this window's terminals, grouped by project like the tab bar; each group's heading shows its project and, for SSH, its host. Switching views keeps each list's search and scroll position. A session whose CLI is already running opens on that process with one click. Search does not include conversation text. All six support local browsing, preview, and resume. See the [full capability table](../../README.md#supported-clis).

Click the new-window button in the preview's reading toolbar to open a dedicated reading window. Adjust text with **A− / A+**, switch between a readable column and the full window width, jump to the first or latest message, and copy code without starting the CLI. [Reading controls and position memory](session-management.md#preview-before-you-resume).

The **+** at the top of the sidebar, or **⌘N**, opens **New session**: start an installed CLI in a project folder, or choose **Terminal** to open your login shell instead. A project's **+** menu offers the same. Both use SwiftTerm's native AppKit terminal. Project tab groups and [keyboard shortcuts](session-management.md#tab-keyboard-shortcuts) help you switch between open terminals; **Settings → Appearance → Terminal** also lets you import your iTerm2 colors.

## Use another machine over SSH

The remote machine must accept `ssh <host>` without a password prompt and have `rsync` and Claude Code, Codex, Antigravity, Kiro CLI, OpenCode, or Pi installed.

1. Choose **Add SSH host…** in the sidebar.
2. Enter a `~/.ssh/config` alias or `user@hostname`.
3. Browse its projects and resume a session on that host.

Antigravity and OpenCode SSH hosts also need `python3`; deleting Antigravity sessions there needs `lsof`.

The code and CLI run remotely. Supported session files are cached on your Mac. This is terminal access, not graphical remote desktop control. [SSH setup and limits](session-management.md#ssh-hosts).

## Keep work running with tmux

The app includes tmux for this Mac; no Homebrew or separate tmux install is needed. Direct `swift run` builds need **tmux 3.3+**. SSH hosts need their own tmux before launching the session. Close a local tab with **Keep running**, then select its session to reattach. Quitting the app also leaves tmux sessions running; remote tmux sessions survive SSH disconnections.

Keep the machine doing the work awake. Without tmux, closing a terminal tab ends its process. Plain project terminals do not use tmux. [Terminal persistence details](session-storage.md#terminal-persistence).

## If a session or CLI is missing

- In **Projects**, clear the time and CLI filters, then click the affected host's refresh button.
- Confirm the CLI executable works in your usual terminal. New session menus offer only installed CLIs.
- Start one conversation in the CLI so it has history for the app to discover. Kiro sessions need at least one message; OpenCode archived and subagent sessions are excluded.
- Check [session locations and supported environment variables](session-storage.md#session-locations). Remote history uses the host's standard Claude Code, Codex, Antigravity, Kiro CLI, and Pi folders, and the OpenCode database its login shell points to.
- For SSH, confirm passwordless access, `rsync`, and the remote CLI before adding the host.

## Appearance, privacy, and help

Open **Settings** in the sidebar or press ⌘,. **General > Interface language** offers **Follow System** (default), **English**, and **Chinese**. The interface updates immediately and remembers your choice. Appearance and terminal settings also update open terminals in place. **Permissions** shows what macOS allows JustSessions, such as notifications.

JustSessions reads local CLI files and caches supported remote history over SSH. It does not upload conversations to a JustSessions service. The CLIs still communicate with their providers. Sparkle checks for app updates through a JustSessions update server that counts checks per day and app version, without storing IP addresses or identifiers. [Storage and privacy](session-storage.md).

Open **Settings → Help** or **Help → JustSessions Help** for a brief feature overview, remote host setup, what to check when a session is missing, and every keyboard shortcut. To send feedback, use **Send us feedback** or **Report an issue** at the bottom of **Settings → General**. Install **tmux on the remote host** so sessions survive disconnections or closing a tab. The same overview is on the [website Help page](https://yangzichao.github.io/JustSessions/help.html); its issue link opens GitHub.
