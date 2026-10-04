# JustSessions source layout

[Back to JustSessions](../../README.md) · [Build and release](build-and-release.md)

Application paths below are relative to `Sources/JustSessions/`. Tests live in `Tests/JustSessionsTests/`.

- `Models/Activity/`: what a running CLI is doing, and a project's running CLIs summed up.
- `Models/Appearance/`: the app's System, Light, or Dark appearance.
- `Models/Appearance/Themes/`: the named themes, with each theme's light and dark colors in `ThemeColors/`.
- `Models/Conversations/`: the session model, its CLI, and the New, Resume, and Branch actions.
- `Models/Transcript/`: the reading width, a readable column or the full window, shared by the preview and every reading window.
- `Models/Transcript/Markdown/`: parsed prose, fenced code, and table blocks used by conversation reading.
- `Models/Customizations/`: session and project names you set, and pins.
- `Models/Notifications/`: which CLIs just finished a turn or stopped to wait on you, what their notification says, and which moments notify.
- `Models/Permissions/`: the macOS permissions the app depends on, and what macOS says about each.
- `Models/Hosts/`: this Mac and saved SSH hosts, project locations and keys, and each host's refresh status.
- `Models/Sidebar/`: the sidebar's filters, projects with their sessions, and multi-selection.
- `Models/Terminal/Appearance/`: terminal colors, font, and size, and the terminal part of a theme's colors.
- `Models/Terminal/Appearance/ColorSchemes/`: which colors terminals use, the app theme's, a preset, or imported ones, with the preset colors in `Presets/`.
- `Models/Terminal/Tabs/`: where tabs open and which shows after one closes, so each project's tabs stay together; tab groups and their colors.
- `Models/Wording/`: counts and relative times in labels.
- `Services/Store/`: `ConversationStore`, the state the views observe. Each feature extends it from its own folder.
- `Services/Activity/`: reads what each CLI on this Mac is doing, from Claude Code's live registry and Codex session files.
- `Services/Notifications/`: posts notifications through macOS, opens the session a clicked one is about, and saves which moments notify.
- `Services/Permissions/`: reads each permission's status without asking for it, and the System Settings page that changes it.
- `Services/Appearance/`: saves the app's appearance and theme, and sets the appearance on every window.
- `Services/Adapters/`: provider discovery and native arguments, one folder per CLI. Separate adapters make adding another CLI straightforward.
- `Services/Hosts/`: refreshing every host and starting new sessions on any of them.
- `Services/Hosts/InstalledCLIs/`: which CLIs each host has, so new sessions offer only those.
- `Services/Launch/`: CLI executable resolution and process environment.
- `Services/Launch/PlainTerminal/`: opens a plain terminal, a login shell in a project folder that is no session.
- `Services/Remote/`: SSH mirroring, commands on the host, new sessions and folder lookup, deletion, and tmux there.
- `Services/Remote/HostStatus/`: one SSH call per refresh that lists the host's tmux sessions and installed CLIs.
- `Services/Tmux/ThisMac/`: bundled runtime discovery, terminal database environment, compatible server selection, and local persistence.
- `Cloudflare/UpdateFeed/`: the Worker at the app's `SUFeedURL`, which counts update checks per day and app version and redirects to the appcast on GitHub. See [Counting update checks](update-checks.md).
- `Scripts/Release/`: release checks, such as opening the packaged app without the build machine's resource bundles.
- `Scripts/Tmux/`: pinned source builds, license collection, and relocated runtime verification for app packaging and CI.
- `Services/Tmux/`: tmux session names, and keeping a CLI running after its tab closes, on any host.
- `Services/Tmux/ThisMac/`: this Mac's own tmux server, its version check, and finding each tab's CLI process.
- `Services/Terminal/`: active pseudo-terminal sessions and process lifecycle.
- `Services/Terminal/Appearance/`: saves terminal colors, font, and size, and applies them with the theme's colors to every terminal.
- `Services/Terminal/Appearance/Import/`: reads colors from iTerm2's default profile or an `.itermcolors` file, only when asked.
- `Services/Terminal/NewSessionDiscovery/`: finds the session a new tab's CLI is writing and links the tab to it.
- `Services/Terminal/AppearingSessions/`: links a new tab to the first session that appears in its project, for SSH hosts and for CLIs that don't reveal the session they write.
- `Services/Processes/`: process tree, open files, and short helper processes with a timeout.
- `Services/Transcript/`: read-only conversation readers for the preview.
- `Services/Transcript/Markdown/`: splits Markdown into prose, code blocks, and tables for the native views.
- `Views/Browser/`: window layout, with folders for the sidebar, the terminal tab bar, and the New session sheet.
- `Views/Browser/Tabs/Groups/`: a project's tab group in the tab bar: its colored label and its tabs.
- `Views/Browser/SidebarToggle/`: the title bar button and View menu command that hide or show the sidebar.
- `Views/Browser/Sidebar/`: sidebar header and footer, with a folder each for filters, hosts, projects, session rows, and multi-selection.
- `Views/Browser/Sidebar/Hosts/`: host headings, and the Add SSH host button and sheet.
- `Views/Terminal/`: a tab's embedded terminal.
- `Views/Preview/`: conversation preview for the selected session.
- `Views/Preview/Markdown/`: formatted prose, horizontally scrolling code and tables, and code copying.
- `Views/Preview/Reading/` and `ReadingPosition/`: text size, reading width, first/latest-message controls, and reading-position restoration.
- `Views/Preview/ReadingWindow/`: one independent, read-only window per host-qualified session.
- `Models/Transcript/Search/`, `Services/Transcript/Search/`, and `Views/Preview/Search/`: temporary per-reader text matching, keyboard shortcuts, highlights, and navigation to occurrences in the displayed transcript.
- `Views/Indicators/`: a session's status glyphs, the working spinner among them, and the pin.
- `Views/SessionActions/`: copying ids and paths, and showing files in Finder, for the menus.
- `Views/Settings/`: General (language, launch behavior, and notifications), Appearance, and Permissions tabs.
- `Views/Settings/Appearance/`: the app's appearance and theme in `App/`, then its terminals' colors, font, and preview in `Terminal/`, with the color scheme and iTerm2 import menus in `Terminal/Colors/`.
- `Views/Settings/Permissions/`: each permission's status and a link to its page in System Settings.
- `Models/Localization/`, `Services/Localization/`, `Views/Localization/`: resource-driven language selection, native string resolution, and the shared SwiftUI locale. See [localization](localization.md).
- `Localization/Localizable.xcstrings`: the authoritative String Catalog. `Sources/JustSessions/Resources/Localization/` contains generated SwiftPM resources.
- `Views/Help/`: feature overview, SSH setup, and links to create a GitHub issue or email a bug report. `Models/App/AppLinks.swift` holds the destinations.
- `Views/Theme/`: the chosen theme's colors, and button styles.
- `Views/Branding/`: the app mark drawn in the sidebar header.

The product website is separate from the app: `website/` contains static pages and focused stylesheets, and `Scripts/Website/` assembles and validates its Pages artifact. Documentation is indexed in [docs/README.md](../README.md). See [website development](website.md) for page metadata, app colors, and publishing.
