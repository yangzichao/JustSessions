# JustSessions source layout

[Back to JustSessions](../../README.md) · [Build and release](build-and-release.md)

Application paths below are relative to `Sources/JustSessions/`. Tests live in `Tests/JustSessionsTests/`.

- `Models/Activity/`: what a running CLI is doing, and a project's running CLIs summed up.
- `Models/Appearance/`: the app's System, Light, or Dark appearance.
- `Models/Appearance/Themes/`: the named themes, with each theme's light and dark colors in `ThemeColors/`.
- `Models/Conversations/`: the session model, its CLI, and the New, Resume, and Branch actions.
- `Models/Customizations/`: session and project names you set, and pins.
- `Models/Hosts/`: this Mac and saved SSH hosts, project locations and keys, and each host's refresh status.
- `Models/Sidebar/`: the sidebar's filters, projects with their sessions, and multi-selection.
- `Models/Terminal/Appearance/`: terminal colors, font, and size, and the terminal part of a theme's colors.
- `Models/Wording/`: counts and relative times in labels.
- `Services/Store/`: `ConversationStore`, the state the views observe. Each feature extends it from its own folder.
- `Services/Activity/`: reads what each CLI on this Mac is doing, from Claude Code's live registry and Codex session files.
- `Services/Appearance/`: saves the app's appearance and theme, and sets the appearance on every window.
- `Services/Adapters/`: provider discovery and native arguments, one folder per CLI. Separate adapters make adding another CLI straightforward.
- `Services/Hosts/`: refreshing every host and starting new sessions on any of them.
- `Services/Launch/`: CLI executable resolution and process environment.
- `Services/Remote/`: SSH mirroring, commands on the host, new sessions and folder lookup, deletion, and tmux there.
- `Services/Tmux/`: tmux session names, and keeping a CLI running after its tab closes, on any host.
- `Services/Tmux/ThisMac/`: this Mac's own tmux server, its version check, and finding each tab's CLI process.
- `Services/Terminal/`: active pseudo-terminal sessions and process lifecycle.
- `Services/Terminal/Appearance/`: saves terminal colors, font, and size, and applies them with the theme's colors to every terminal.
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
- `Views/Settings/`: the Settings window, with an Appearance tab for the whole app's appearance and theme, and a Terminal tab.
- `Views/Theme/`: the chosen theme's colors, and button styles.
- `Views/Branding/`: the app mark drawn in the sidebar header.
