<p align="center">
  <img src="Branding/PNG/app-icon-256.png" width="128" height="128" alt="JustSessions app icon">
</p>

<h1 align="center">JustSessions</h1>

<p align="center">
  <b>A native macOS session manager for Claude Code, OpenAI Codex CLI, and Google Antigravity CLI.</b><br>
  Browse, search, preview, resume, and branch every AI coding agent session from one window.
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

---

Claude Code, Codex, and Antigravity each keep their own session history in hidden folders, and `claude --resume` or `codex resume` only show one CLI and one project at a time. JustSessions scans all of them, groups sessions by project, shows a read-only preview of each conversation, and resumes the one you pick in its own CLI inside an embedded terminal. Machines you reach over SSH are listed the same way as this Mac, each under its own heading.

## Download

1. Download **[JustSessions.dmg](https://github.com/yangzichao/JustSessions/releases/latest/download/JustSessions.dmg)** (latest release, signed and notarized by Apple).
2. Open it and drag **JustSessions** into **Applications**.
3. Launch it from Applications. Updates install automatically through Sparkle.

Requirements: macOS 14 Sonoma or later on Apple Silicon, plus at least one of the CLIs installed: `claude`, `codex`, or `agy`.

## Features

**Find any session**
- All Claude Code, Codex, and Antigravity CLI sessions in one sidebar, grouped by machine (this Mac, then each SSH host), then by project folder, sorted by recent activity.
- Search projects by name or path, and sessions by title or session ID.
- Filter to sessions from the past seven days, or to one CLI.
- Pin projects and sessions to keep them at the top. Rename any session locally without touching the CLI's own title.

**Preview before you resume**
- Read a Claude Code or Codex conversation without starting the CLI. Your messages and the agent's replies are shown; runs of tool calls collapse into one expandable row.

**Resume, branch, and start sessions**
- Resume a session in its native CLI inside an embedded terminal: double-click it, use **Resume**, or right-click.
- Branch (fork) a Claude Code or Codex conversation into a new session. This forks the conversation, not a Git branch.
- Start a new session in any project folder, on this Mac or an SSH host, with any supported CLI. It appears in the sidebar right away.
- Keep several terminal tabs open. Select a session in the sidebar to read its preview, or select a terminal tab to return to its CLI without stopping it.
- With tmux 3.3 or later installed, a CLI on this Mac runs inside tmux. Closing its tab with **Keep running**, quitting the app, or installing an update leaves it running. Resume the session to reattach, or right-click it and choose **End on this Mac**.
- Pick up names set with `/rename` in Claude Code within about a second.
- See what each CLI is doing on its sidebar row, its project, and its tab: a turning arc while it works, an amber mark while it waits on your answer, a green dot while it waits for your next prompt, and a hollow circle once it ended in a tab still open. A session nothing runs shows how long ago it was active instead. Claude Code and Codex on this Mac tell what they are doing, also while they run in tmux with no tab open; elsewhere the green dot only says the CLI runs.

**SSH hosts**
- Click **Add SSH host…** at the bottom left of the sidebar and enter a host from `~/.ssh/config` or `user@hostname`. Its Claude Code and Codex sessions are listed under its own heading, below this Mac's.
- Resume, branch, start, and delete sessions on the host over SSH, just like on this Mac.
- Refresh updates every host at once. A host that can't be reached shows the error on its heading; the others still list.
- With tmux on the host, a session there keeps running when the connection drops or the tab closes. Resume to reattach.

**Clean up**
- Delete sessions one at a time, in a multi-selection (⌘-click, ⇧-click), or per project, always after a confirmation.
- Claude Code sessions on this Mac go to the macOS Trash. Codex uses `codex delete --force`. SSH hosts have no Trash, so deletions there are permanent.
- Sessions with an open terminal tab, or still running in tmux, can't be deleted.

## How it works

JustSessions reads session files that already exist on your Mac. It never uploads them anywhere.

| CLI | Where sessions are read from | Preview | Branch | Delete |
| --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/projects` (honors `CLAUDE_CONFIG_DIR`) | Yes | Yes | Yes |
| OpenAI Codex CLI | `~/.codex/sessions` (honors `CODEX_HOME`) | Yes | Yes | Yes |
| Google Antigravity CLI | `~/.gemini/antigravity-cli/conversations` | Not yet | Use `/fork` after resuming | No |

The app runs each CLI in a pseudo-terminal with the original project as its working directory, using the CLI's own resume and fork commands. When started from Finder, it looks for CLIs and tmux in the inherited `PATH` plus `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. Scanning reads the session files and runs no shell command; with tmux installed, it also asks tmux for its version and running sessions.

With tmux 3.3 or later, each CLI on this Mac runs in the app's own tmux server, which ignores `~/.tmux.conf` and leaves your other tmux sessions alone. `tmux -L justsessions ls` lists its sessions. Without tmux, the CLI runs directly. In a tmux tab, dragging selects through tmux and copies to the clipboard when you let go; hold Shift while dragging to select the usual way. Shift-Return still adds a new line in Claude Code.

Claude Code reports whether it is working or waiting on you in `~/.claude/sessions`; a Codex session file records when each turn starts and ends. The app reads both about once a second.

SSH hosts must accept `ssh <host>` without a password prompt and need `rsync`. Their session files are mirrored into a local cache and read by the same code as this Mac's.

## FAQ

**How do I see all my Claude Code sessions across projects?**
Open JustSessions. Every project under `~/.claude/projects` is listed in the sidebar with its sessions, and search covers all of them at once.

**How do I resume an old Claude Code or Codex session?**
Find it in the sidebar and double-click it. The app runs the CLI's own resume command in the session's original folder.

**Can I fork a Claude Code conversation?**
Yes. **Branch** creates a new session from an existing Claude Code or Codex conversation and opens it in a new tab.

**Does it work with sessions on a remote server?**
Yes, for Claude Code and Codex. Click **Add SSH host…** at the bottom left of the sidebar and enter the host. Its sessions appear under its own heading; hover the heading and click **+** to start a new session there.

**Is it free?**
Yes. JustSessions is open source under the MIT license.

## Build from source

Requires macOS 14+ and Xcode Command Line Tools.

```sh
swift test
./Scripts/build-app.sh
open "dist/JustSessions.app"
```

Pushes to `main` and pull requests run `swift test`. Pushing a version tag makes GitHub Actions build, Developer ID sign, notarize, and publish the app; the tag sets the app version:

```sh
git tag v0.23.0
git push origin v0.23.0
```

Each release includes the notarized `JustSessions.dmg`, plus `appcast.xml` and the Sparkle-signed `JustSessions.zip` used for updates. CI signing uses the repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_NOTARY_KEY`, `APPLE_NOTARY_ISSUER_ID`, `APPLE_NOTARY_KEY_ID`, and `SPARKLE_EDDSA_PRIVATE_KEY`.

### Source layout

- `Models/Activity/`: what a running CLI is doing, and a project's running CLIs summed up.
- `Models/Conversations/`: the session model, its CLI, and the New, Resume, and Branch actions.
- `Models/Customizations/`: session and project names you set, and pins.
- `Models/Hosts/`: this Mac and saved SSH hosts, project locations and keys, and each host's refresh status.
- `Models/Sidebar/`: the sidebar's filters, projects with their sessions, and multi-selection.
- `Models/Wording/`: counts and relative times in labels.
- `Services/Store/`: `ConversationStore`, the state the views observe. Each feature extends it from its own folder.
- `Services/Activity/`: reads what each CLI on this Mac is doing, from Claude Code's live registry and Codex session files.
- `Services/Adapters/`: provider discovery and native arguments, one folder per CLI. Separate adapters make adding another CLI straightforward.
- `Services/Hosts/`: refreshing every host and starting new sessions on any of them.
- `Services/Launch/`: CLI executable resolution and process environment.
- `Services/Remote/`: SSH mirroring, commands on the host, new sessions and folder lookup, deletion, and tmux there.
- `Services/Tmux/`: tmux session names, and keeping a CLI running after its tab closes, on any host.
- `Services/Tmux/ThisMac/`: this Mac's own tmux server, its version check, and finding each tab's CLI process.
- `Services/Terminal/`: active pseudo-terminal sessions and process lifecycle.
- `Services/Terminal/NewSessionDiscovery/`: finds the session a new tab's CLI is writing and links the tab to it.
- `Services/Processes/`: process tree, open files, and short helper processes with a timeout.
- `Services/Transcript/`: read-only conversation readers for the preview.
- `Views/Browser/`: window layout, with folders for the sidebar, the terminal tab bar, and the New session sheet.
- `Views/Browser/Sidebar/`: sidebar header and footer, with a folder each for filters, hosts, projects, session rows, and multi-selection.
- `Views/Browser/Sidebar/Hosts/`: host headings, and the Add SSH host button and sheet.
- `Views/Terminal/`: a tab's embedded terminal.
- `Views/Preview/`: conversation preview for the selected session.
- `Views/Indicators/`: a session's status glyphs, the working spinner among them, and the pin.
- `Views/SessionActions/`: copying ids and paths, and showing files in Finder, for the menus.
- `Views/Theme/`: colors and button styles.
- `Views/Branding/`: the app mark drawn in the sidebar header.

## License

MIT. The embedded terminal uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) under its MIT license.
