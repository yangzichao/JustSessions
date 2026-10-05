<p align="center">
  <img src="Branding/PNG/app-icon-256.png" width="96" height="96" alt="JustSessions macOS app icon">
</p>

<h1 align="center">JustSessions — AI Coding Session Manager for macOS</h1>

<p align="center">
  <b>Lightweight. All your sessions.</b><br>
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

**A lightweight home for your coding sessions.** JustSessions organizes the history your CLIs already create in one native Mac app. Search projects and sessions, preview their conversations, and resume in the original CLI and project folder.

[Website](https://yangzichao.github.io/JustSessions/) · [Download](#download) · [Getting started](docs/guides/getting-started.md) · [SSH](#remote-sessions-over-ssh) · [tmux](#keep-sessions-running-with-tmux) · [Supported CLIs](#supported-clis) · [Documentation](docs/README.md)

![The real Claude Code CLI running in JustSessions, with two Claude Code sessions, Codex, OpenCode, and Pi grouped under one project in Open tabs](docs/images/native-terminal.jpg)

*Real Claude Code CLI, showing its local help screen in a sample project.*

## Features

- **Find:** search project names and paths, session titles, and IDs. Pin and rename sessions you return to.
- **Read:** preview supported conversations, find text with ⌘F, adjust text size, switch between a readable column and the full window width, copy code, and open a dedicated reading window without starting the CLI. Long histories load automatically as you scroll, and images you attached or a tool returned show in place for Claude Code, Codex, and Pi. [Reading controls](docs/guides/session-management.md#preview-before-you-resume).
- **Resume or branch:** continue in an embedded terminal, or fork a supported conversation to try another approach.
- **Organize:** group terminal tabs by project, open a plain project terminal, and switch tabs with familiar keyboard shortcuts.
- **Stay informed:** local Claude Code and Codex sessions can notify when a turn finishes or needs your input.
- **Make it yours:** system, English, or Chinese interface language; six app themes, light and dark appearances, terminal color schemes or your own iTerm2 colors, and terminal font settings that update open terminals.

## Native terminal

**Your agents and shell, in project tabs.** JustSessions embeds SwiftTerm's native AppKit terminal. Run your CLI or open a plain project shell, switch with **Open tabs**, and import your iTerm2 colors.

**Two terminals, side by side.** Keep an agent beside your shell, or compare sessions. Click a pane to focus it and drag the divider to make room. [Split view](docs/guides/session-management.md#resume-branch-and-start-sessions).

![JustSessions Open tabs sidebar with five tabs across two projects, alongside the real Claude Code CLI and a project shell displaying Git diff in split view](docs/images/split-terminal.jpg)

*Real Claude Code CLI and shell in split view, using a sample Git project.*

## Read before you resume

![JustSessions' conversation reader, with reading controls and sessions grouped by project and machine](docs/images/session-overview.jpg)

*Real app interface with sample projects and conversations.*

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
  <img src="docs/images/tmux-keep-running.jpg" width="900" alt="The full JustSessions window with the same Claude Code CLI reattached in tmux after quitting and reopening the app">
</p>

*Real Claude Code CLI, reattached after quitting and reopening the app. Sample project.*

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
3. Choose **Projects** in the sidebar to browse sessions, or **Open tabs** to switch between open terminals. Select a supported session to read its preview.
4. Double-click a session or choose **Resume** to continue in its original CLI.

App updates are delivered through Sparkle; check manually in **Settings → General**. [Getting started](docs/guides/getting-started.md) covers your first session, missing CLIs, SSH, and tmux. The same quick guide is available on the [website](https://yangzichao.github.io/JustSessions/guide.html).

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
- [Session management guide](docs/guides/session-management.md): pins, project tab groups, split view, shortcuts, notifications, SSH hosts, cleanup, and appearance.
- [Session storage and privacy](docs/guides/session-storage.md): history locations, remote caching, and tmux behavior.
- [Build and release](docs/development/build-and-release.md): Make commands and release signing.
- [Source layout](docs/development/source-layout.md): where each feature lives.
- [Counting update checks](docs/development/update-checks.md): how daily update checks estimate active installs without collecting user data.
- [Website development](docs/development/website.md): preview, validate, and publish the GitHub Pages site.
- [All documentation](docs/README.md) · [Release notes](https://github.com/yangzichao/JustSessions/releases) · [Guide](https://yangzichao.github.io/JustSessions/guide.html)

On first launch, a short tour points out your sessions, **New session**, and SSH hosts, and later tips explain each feature the first time you reach it; choose **Help → Take the Tour** to see the tour and its tips again. In the app, open **Settings → Help** or **Help → JustSessions Help** for a brief feature overview, SSH setup, what to check when a session is missing, and every keyboard shortcut. Install **tmux on each remote host** to keep its sessions running after a disconnect or closing a tab.

For feedback, choose **Send us feedback** at the bottom of **Settings → General** to open an email to [zichaoyangphys@gmail.com](mailto:zichaoyangphys@gmail.com), or **Report an issue** to open a GitHub issue. Both start with your app and macOS versions filled in, and both are also in the website Guide’s [Feedback section](https://yangzichao.github.io/JustSessions/guide.html#feedback).

## License

[MIT](LICENSE). The embedded terminal uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) under its MIT license.
