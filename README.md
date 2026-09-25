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

Claude Code, Codex, and Antigravity each keep their own session history in hidden folders, and `claude --resume` or `codex resume` only show one CLI and one project at a time. JustSessions scans all of them, groups sessions by project, shows a read-only preview of each conversation, and resumes the one you pick in its own CLI inside an embedded terminal. It also lists sessions from remote machines over SSH.

## Download

1. Download **[JustSessions.dmg](https://github.com/yangzichao/JustSessions/releases/latest/download/JustSessions.dmg)** (latest release, signed and notarized by Apple).
2. Open it and drag **JustSessions** into **Applications**.
3. Launch it from Applications. Updates install automatically through Sparkle.

Requirements: macOS 14 Sonoma or later on Apple Silicon, plus at least one of the CLIs installed: `claude`, `codex`, or `agy`.

## Features

**Find any session**
- All Claude Code, Codex, and Antigravity CLI sessions in one sidebar, grouped by project folder and sorted by recent activity.
- Search projects by name or path, and sessions by title or session ID.
- Filter to sessions from the past seven days, or to one CLI.
- Pin projects and sessions to keep them at the top. Rename any session locally without touching the CLI's own title.

**Preview before you resume**
- Read a Claude Code or Codex conversation without starting the CLI. Your messages and the agent's replies are shown; runs of tool calls collapse into one expandable row.

**Resume, branch, and start sessions**
- Resume a session in its native CLI inside an embedded terminal: double-click it, use **Resume**, or right-click.
- Branch (fork) a Claude Code or Codex conversation into a new session. This forks the conversation, not a Git branch.
- Start a new session in any project folder with any supported CLI. It appears in the sidebar right away.
- Keep several terminal tabs open. Switch between a running CLI and the preview without stopping it.
- Pick up names set with `/rename` in Claude Code within about a second.

**Remote SSH hosts**
- Add a host from `~/.ssh/config` or `user@hostname`, and its Claude Code and Codex sessions are listed next to your local ones.
- Resume, branch, start, and delete remote sessions over SSH.
- With tmux on the host, a remote session keeps running when the connection drops or the tab closes. Resume to reattach.

**Clean up**
- Delete sessions one at a time, in a multi-selection (⌘-click, ⇧-click), or per project, always after a confirmation.
- Local Claude Code sessions go to the macOS Trash. Codex uses `codex delete --force`. Remote deletions are permanent.
- Sessions with an open terminal tab can't be deleted.

## How it works

JustSessions reads session files that already exist on your Mac. It never uploads them anywhere.

| CLI | Where sessions are read from | Preview | Branch | Delete |
| --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/projects` (honors `CLAUDE_CONFIG_DIR`) | Yes | Yes | Yes |
| OpenAI Codex CLI | `~/.codex/sessions` (honors `CODEX_HOME`) | Yes | Yes | Yes |
| Google Antigravity CLI | `~/.gemini/antigravity-cli/conversations` | Not yet | Use `/fork` after resuming | No |

The app launches each CLI directly in a pseudo-terminal with the original project as its working directory, using the CLI's own resume and fork commands. When started from Finder, it looks for CLIs in the inherited `PATH` plus `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. No shell command runs during scanning.

Remote hosts must accept `ssh <host>` without a password prompt and need `rsync`. Their session files are mirrored into a local cache and read by the same code as local sessions.

## FAQ

**How do I see all my Claude Code sessions across projects?**
Open JustSessions. Every project under `~/.claude/projects` is listed in the sidebar with its sessions, and search covers all of them at once.

**How do I resume an old Claude Code or Codex session?**
Find it in the sidebar and double-click it. The app runs the CLI's own resume command in the session's original folder.

**Can I fork a Claude Code conversation?**
Yes. **Branch** creates a new session from an existing Claude Code or Codex conversation and opens it in a new tab.

**Does it work with sessions on a remote server?**
Yes, for Claude Code and Codex. Click **Remote** at the bottom of the sidebar and add the SSH host.

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

- `Models/`: shared conversation model.
- `Models/Remote/`: saved SSH hosts and remote project keys.
- `Services/Adapters/`: provider discovery and native arguments. Separate adapters make adding another CLI straightforward.
- `Services/Launch/`: CLI executable resolution and process environment.
- `Services/Remote/`: SSH mirroring, remote commands, new sessions, deletion, and tmux.
- `Services/Terminal/`: active pseudo-terminal sessions and process lifecycle.
- `Services/Terminal/NewSessionDiscovery/`: finds the session a new tab's CLI is writing and links the tab to it.
- `Services/Processes/`: process tree, open files, and short helper processes with a timeout.
- `Services/Transcript/`: read-only conversation readers for the preview.
- `Views/Browser/`: sidebar, terminal tab bar, and window layout.
- `Views/Browser/Sidebar/`: sidebar header, filters, section headings, and session rows.
- `Views/Remote/`: remote hosts sheet and tmux status.
- `Views/Branding/`: the app mark drawn in the sidebar header.
- `Views/Preview/`: conversation preview for the selected session.

## License

MIT. The embedded terminal uses [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) under its MIT license.
