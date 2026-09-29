<p align="center">
  <img src="Branding/PNG/app-icon-256.png" width="96" height="96" alt="JustSessions macOS app icon">
</p>

<h1 align="center">JustSessions — AI Session Manager for macOS</h1>

<p align="center">
  <b>Find the right AI coding session. Pick up where you left off.</b><br>
  A lightweight, native macOS app for Claude Code, OpenAI Codex CLI, and Google Antigravity CLI.<br>
  Local projects, remote machines over SSH, and sessions that keep running with tmux.
</p>

<p align="center">
  <a href="https://github.com/yangzichao/JustSessions/releases/latest/download/JustSessions.dmg"><img src="https://img.shields.io/badge/Download-JustSessions.dmg-2F6BFF?style=for-the-badge&logo=apple&logoColor=white" alt="Download JustSessions for macOS"></a>
</p>

<p align="center">
  <a href="https://github.com/yangzichao/JustSessions/releases/latest"><img src="https://img.shields.io/github/v/release/yangzichao/JustSessions?label=release" alt="Latest release"></a>
  <a href="https://github.com/yangzichao/JustSessions/releases"><img src="https://img.shields.io/github/downloads/yangzichao/JustSessions/total" alt="Total downloads"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/Apple%20Silicon-arm64-black" alt="Apple Silicon">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/yangzichao/JustSessions" alt="MIT license"></a>
</p>

You remember the work. Finding the conversation takes longer: which project, which terminal, which AI tool, which machine?

**JustSessions brings your AI coding session history into one window.** Search across projects, preview Claude Code and Codex conversations, then resume the right session in its original CLI and working directory. Keep using your editor, CLI configuration, and provider accounts.

[Download for macOS](#download) · [Remote sessions](#your-desktop-at-home-your-mac-on-the-go) · [tmux persistence](#close-the-tab-keep-the-work-running-with-tmux) · [Supported CLIs](#supported-clis) · [User guide](docs/guides/session-management.md)

![JustSessions on macOS showing AI coding sessions grouped by project and machine, with a Claude Code conversation preview](docs/images/session-overview.jpg)

*Actual JustSessions interface with sample projects and conversations. Read the context before you resume.*

## Features

Built for developers who work across multiple projects, AI coding tools, or SSH hosts.

| When this gets in your way… | JustSessions helps you… |
| --- | --- |
| “Which session had the work I need?” | Find sessions by title or ID, or find their project by name or path. Pin and rename the ones you return to. |
| “I keep reopening sessions to remember what happened.” | Read Claude Code and Codex conversations before starting the CLI, with tool calls collapsed out of the way. |
| “My work is spread across Claude Code, Codex, and terminal tabs.” | Browse supported CLIs together, grouped by machine and project, and resume in an embedded terminal. |
| “I want to try another approach from this conversation.” | Branch a Claude Code or Codex session into a new conversation. |

## Your desktop at home, your Mac on the go

The agent is running on your desktop or development server. You are working from your laptop. **Add the machine over SSH and continue its Claude Code or Codex sessions from JustSessions.**

- See **This Mac** and each remote host in the same sidebar, with their own projects and sessions.
- Preview the conversation, then resume, branch, or start a session in the remote project directory.
- Keep the code and CLI execution on that machine. JustSessions caches its session history locally for browsing.

![JustSessions displaying a Claude Code conversation on the dev-desktop SSH host alongside local projects and a build server](docs/images/remote-desktop-sessions.jpg)

*Sample remote desktop and server sessions in the real app interface. Connections use SSH; JustSessions manages terminal sessions, not graphical screen sharing.*

Use an existing `~/.ssh/config` alias or `user@hostname`. The host needs passwordless SSH access, `rsync`, and the CLI you use. [Set up a remote host](docs/guides/session-management.md#ssh-hosts).

## Close the tab. Keep the work running with tmux.

**Leaving the window does not have to end the job.** With tmux available when a session launches, its process can keep running after you close the tab or quit JustSessions. On a remote host, tmux also keeps the session alive when the SSH connection drops.

1. Launch a session with tmux installed on the machine doing the work.
2. Close its terminal tab and choose **Keep running**.
3. Return to the session and choose **Resume** to reattach to the running process.

<p align="center">
  <img src="docs/images/tmux-keep-running.jpg" width="360" alt="JustSessions close-tab dialog offering Keep running to leave a terminal session running in tmux">
</p>

*The app's actual close-tab dialog, shown with a sample process running in an isolated tmux session.*

This Mac requires **tmux 3.3+**; remote sessions require tmux on the SSH host. The host must stay awake and running. Without tmux, closing the tab ends the terminal process. [How session persistence works](docs/guides/session-storage.md#terminal-persistence).

## Lightweight by design

- **Native SwiftUI app.** The [v0.24.0 Mac installer](https://github.com/yangzichao/JustSessions/releases/tag/v0.24.0) is about **4 MB**.
- **Works with the history you already have.** Open the app to discover existing sessions. No manual import or JustSessions account to set up.
- **Uses your existing CLIs.** Your CLI's commands, configuration, and authentication stay part of your workflow.
- **Free and open source.** MIT licensed. JustSessions adds no subscription; your AI providers' own pricing still applies.

## Download

**Requires macOS 14 Sonoma or later on Apple Silicon.** Install and sign in to at least one supported CLI: `claude`, `codex`, or `agy`.

1. Download **[JustSessions.dmg](https://github.com/yangzichao/JustSessions/releases/latest/download/JustSessions.dmg)**, Developer ID signed and notarized by Apple.
2. Open it, drag **JustSessions** into **Applications**, and launch it.
3. Find a project or session in the sidebar. Select a Claude Code or Codex session to read its preview.
4. Double-click a session or choose **Resume** to continue in its original CLI.

App updates are delivered through Sparkle. For remote sessions, use **Add SSH host…** in the sidebar; see the [SSH setup instructions](docs/guides/session-management.md#ssh-hosts).

## Supported CLIs

| Capability | Claude Code | OpenAI Codex CLI | Google Antigravity CLI |
| --- | --- | --- | --- |
| Browse, search, and resume local sessions | Yes | Yes | Yes |
| Read a conversation preview | Yes | Yes | Not yet |
| Branch a conversation from the app | Yes | Yes | Use `/fork` inside the CLI |
| Browse and manage sessions over SSH | Yes | Yes | Not yet |
| Delete sessions from the app | Yes | Yes | Not yet |

Search matches project names and paths, session titles, and session IDs. It does not search the full conversation text. **Branch** forks a conversation; it does not create a Git branch.

## How it works

JustSessions reads the history files your CLIs already create and launches the selected CLI in an embedded terminal. It does not upload conversation history to a JustSessions service. Adding an SSH host copies its supported session files to a local cache over SSH; the CLIs you run still communicate with their providers as usual.

[Session storage and privacy](docs/guides/session-storage.md) explains file locations, CLI discovery, SSH caching, and optional tmux persistence.

## FAQ

### How do I find Claude Code sessions across projects?

Open JustSessions and search by project name, folder path, session title, or session ID. Sessions are grouped by project, so you can browse your history without remembering the original terminal tab.

### Can I manage Claude Code and Codex sessions in the same app?

Yes. JustSessions is a macOS session manager for both, with conversation previews, resume, branching, and SSH support. Antigravity CLI sessions can also be browsed and resumed locally.

### How do I resume an old Codex or Claude Code session?

Find it in the sidebar and double-click it. JustSessions uses that CLI's own resume command in the session's original working directory. For a session still running in an app-managed tmux session, it reattaches to that process.

### Can I keep an AI coding session running after closing the app?

Yes, with tmux. Install tmux 3.3 or later on this Mac before launching the session; for an SSH session, tmux must be available on the host. Choose **Keep running** when closing a local terminal tab. See the [terminal persistence guide](docs/guides/session-storage.md#terminal-persistence).

### Do I need Remote Desktop to use a session on another computer?

For supported CLI sessions, connect that computer over SSH from JustSessions. You can browse its Claude Code and Codex history and work in its terminal from your Mac. Graphical desktop access, such as controlling other applications through RDP or VNC, is outside JustSessions' scope.

### Does JustSessions need a new AI account or subscription?

No. Use your existing CLI authentication and provider accounts. JustSessions itself is free, open source, and requires no account. Any model usage is billed or limited by your existing provider plan.

## Documentation and development

- [Session management guide](docs/guides/session-management.md): pins, terminal tabs, activity indicators, SSH hosts, and cleanup.
- [Session storage and privacy](docs/guides/session-storage.md): history locations, remote caching, and tmux behavior.
- [Build and release](docs/development/build-and-release.md): Swift build commands and release signing.
- [Source layout](docs/development/source-layout.md): where each feature lives.
- [Release notes](https://github.com/yangzichao/JustSessions/releases) · [Bug reports and feature requests](https://github.com/yangzichao/JustSessions/issues)

## License

[MIT](LICENSE). The embedded terminal uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) under its MIT license.
