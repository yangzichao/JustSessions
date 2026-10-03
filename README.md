<p align="center">
  <img src="Branding/PNG/app-icon-256.png" width="96" height="96" alt="JustSessions macOS app icon">
</p>

<h1 align="center">JustSessions — AI Coding Session Manager for macOS</h1>

<p align="center">
  <b>Find the right AI coding session. Pick up where you left off.</b><br>
  A lightweight, native macOS app for Claude Code, OpenAI Codex CLI, Google Antigravity CLI, Kiro CLI, OpenCode, and Pi.<br>
  Local projects, remote machines over SSH, and sessions that keep running with tmux.
</p>

<p align="center">
  <a href="https://github.com/yangzichao/JustSessions/releases/latest/download/JustSessions.dmg"><img src="https://img.shields.io/badge/Download-JustSessions.dmg-15171C?style=for-the-badge&logo=apple&logoColor=white" alt="Download JustSessions for macOS"></a>
</p>

<p align="center">
  <a href="https://github.com/yangzichao/JustSessions/releases/latest"><img src="https://img.shields.io/github/v/release/yangzichao/JustSessions?label=release" alt="Latest release"></a>
  <a href="https://github.com/yangzichao/JustSessions/releases"><img src="https://img.shields.io/github/downloads/yangzichao/JustSessions/total" alt="Total downloads"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/Apple%20Silicon-arm64-black" alt="Apple Silicon">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/yangzichao/JustSessions" alt="MIT license"></a>
</p>

**Find the conversation you need without hunting through terminal tabs.** JustSessions brings your AI coding history into one native Mac app. Search projects and sessions, preview their conversations, and resume in the original CLI and project folder.

[Website](https://yangzichao.github.io/JustSessions/) · [Download](#download) · [Getting started](docs/guides/getting-started.md) · [SSH](#remote-sessions-over-ssh) · [tmux](#keep-sessions-running-with-tmux) · [Supported CLIs](#supported-clis) · [Documentation](docs/README.md)

![JustSessions on macOS showing AI coding sessions grouped by project and machine, with a Claude Code conversation preview](docs/images/session-overview.jpg)

*Real app interface with sample projects and conversations.*

## Features

- **Find:** search project names and paths, session titles, and IDs. Pin and rename sessions you return to.
- **Read:** preview supported conversations, find text with ⌘F, adjust text size, switch between a readable column and the full window width, copy code, and open a dedicated reading window without starting the CLI. Long histories load automatically as you scroll. [Reading controls](docs/guides/session-management.md#preview-before-you-resume).
- **Resume or branch:** continue in an embedded terminal, or fork a supported conversation to try another approach.
- **Organize:** group terminal tabs by project, open a plain project terminal, and switch tabs with familiar keyboard shortcuts.
- **Stay informed:** local Claude Code and Codex sessions can notify when a turn finishes or needs your input.
- **Make it yours:** system, English, or Chinese interface language; six app themes, light and dark appearances, and terminal font settings that update open terminals.

## Remote sessions over SSH

**Use your Mac to continue Claude Code, Codex, Antigravity, Kiro CLI, OpenCode, and Pi sessions on a desktop or development server.** Add a passwordless SSH host with `rsync` and the CLI installed. The code and CLI stay on that machine; JustSessions caches session history locally.

![JustSessions displaying a Claude Code conversation on the dev-desktop SSH host alongside local projects and a build server](docs/images/remote-desktop-sessions.jpg)

*Real app interface with sample SSH hosts and conversations. JustSessions provides terminal access, not graphical screen sharing.*

Use a `~/.ssh/config` alias or `user@hostname`. [Set up an SSH host](docs/guides/session-management.md#ssh-hosts).

## Keep sessions running with tmux

**Close the tab or quit the app, then reattach to the same process.** The packaged app includes tmux for this Mac. Remote tmux sessions also survive an SSH disconnection.

1. Launch a session on this Mac, or on an SSH host with tmux installed.
2. Close its terminal tab and choose **Keep running**.
3. Click the session in the sidebar to reattach to the running process.

<p align="center">
  <img src="docs/images/tmux-keep-running.jpg" width="360" alt="JustSessions close-tab dialog offering Keep running to leave a terminal session running in tmux">
</p>

*The app's actual close-tab dialog, shown with a sample tmux process.*

No separate local tmux install is needed. Direct `swift run` builds need **tmux 3.3+**; SSH hosts need their own tmux. Keep the machine awake. Without tmux, closing the tab ends the terminal process. [How session persistence works](docs/guides/session-storage.md#terminal-persistence).

## Lightweight by design

- **Native SwiftUI and SwiftTerm.** A Mac app with an embedded terminal.
- **No import or new account.** Reads the history your CLIs already create.
- **Your existing tools.** Keep your editor, CLI configuration, and provider authentication.
- **Free and open source.** MIT licensed. Your AI providers' own charges still apply.

## Download

**Requires macOS 14 Sonoma or later on Apple Silicon.** Install and sign in to at least one supported CLI: `claude`, `codex`, `agy`, `kiro-cli`, `opencode`, or `pi`.

1. Download **[JustSessions.dmg](https://github.com/yangzichao/JustSessions/releases/latest/download/JustSessions.dmg)**, Developer ID signed and notarized by Apple.
2. Open it, drag **JustSessions** into **Applications**, and launch it.
3. Find a project or session in the sidebar. Select a supported session to read its preview.
4. Double-click a session or choose **Resume** to continue in its original CLI.

App updates are delivered through Sparkle. [Getting started](docs/guides/getting-started.md) covers your first session, missing CLIs, SSH, and tmux. The same quick guide is available on the [website](https://yangzichao.github.io/JustSessions/guide.html).

## Supported CLIs

| Capability | Claude Code | OpenAI Codex CLI | Google Antigravity CLI | Kiro CLI | OpenCode | Pi |
| --- | --- | --- | --- | --- | --- | --- |
| Browse, search, and resume local sessions | Yes | Yes | Yes | Yes | Yes | Yes |
| Read a conversation preview | Yes | Yes | Yes | Yes | Yes | Yes |
| Branch a conversation from the app | Yes | Yes | Use `/fork` inside the CLI | Use `/rewind` inside the CLI | Yes | Yes |
| Browse and manage sessions over SSH | Yes | Yes | Yes | Yes | Yes | Yes |
| Delete sessions from the app | Yes | Yes | Yes | Yes | Yes | Yes |

New session menus offer only installed CLIs. The sidebar filter includes CLIs that are installed or have saved sessions. Antigravity and Pi sessions on this Mac move to the Trash; SSH Antigravity and OpenCode management needs `python3`, and Antigravity deletion also needs `lsof`. Kiro and OpenCode deletion use their native CLI commands; see the [storage guide](docs/guides/session-storage.md#session-locations).

Search matches project names and paths, session titles, and session IDs. It does not search the full conversation text. **Branch** forks a conversation; it does not create a Git branch.

## How it works

JustSessions reads the history files your CLIs already create and launches the selected CLI in an embedded terminal. It does not upload conversation history to a JustSessions service. Adding an SSH host copies its supported session files to a local cache over SSH; the CLIs you run still communicate with their providers as usual.

[Session storage and privacy](docs/guides/session-storage.md) explains file locations, CLI discovery, SSH caching, and optional tmux persistence.

## Documentation and development

Build locally with `make`; the app is written to `dist/JustSessions.app`. Use `make dev` to build and open it, or `make help` for other commands.

- [Getting started](docs/guides/getting-started.md): install the app, find and resume a session, and troubleshoot discovery.
- [Session management guide](docs/guides/session-management.md): pins, project tab groups, shortcuts, notifications, SSH hosts, cleanup, and appearance.
- [Session storage and privacy](docs/guides/session-storage.md): history locations, remote caching, and tmux behavior.
- [Build and release](docs/development/build-and-release.md): Make commands and release signing.
- [Source layout](docs/development/source-layout.md): where each feature lives.
- [Website development](docs/development/website.md): preview, validate, and publish the GitHub Pages site.
- [All documentation](docs/README.md) · [Release notes](https://github.com/yangzichao/JustSessions/releases) · [Help](https://yangzichao.github.io/JustSessions/help.html)

In the app, use the sidebar's question mark icon or **Help → JustSessions Help** for a brief feature overview and SSH setup. Install **tmux on each remote host** to keep its sessions running after a disconnect or closing a tab.

## License

[MIT](LICENSE). The embedded terminal uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) under its MIT license.
