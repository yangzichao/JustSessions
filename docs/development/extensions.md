# Extensions (design proposal)

[Back to JustSessions](../../README.md) · [Feature requirements](../requirements/README.md) · [Source layout](source-layout.md) · [Performance](performance.md)

**Status:** proposal of 3 November 2026. Nothing here is implemented. Requirement files state current behavior, so each phase adds its `EXT-` lines to a new `requirements/app/extensions.md`, and updates the lines named in [Requirements to update](#requirements-to-update), in the pull request that ships it.

## Decisions

Taken by the project owner on 3 November 2026:

- Four first-party extensions: **Conversation view** (rich rendering, with generated UI from Thesys OpenUI), **Files**, **Changes**, and **Preview**.
- Every extension is off until turned on in **Settings → Extensions**.
- Extension UI is a web page in a `WKWebView`, written against the same bridge API that third-party extensions will use later, as VS Code ships its Git and Markdown support as extensions.
- The conversation view has a message box that types into the CLI. It has no approve or deny buttons: approvals stay in the CLI's own interface (PRD-01).
- SSH hosts are supported from the first version of each extension.

Extensions that add CLIs, commands, or event hooks without UI are a separate track (an out-of-process executable speaking JSON), not part of this proposal.

## What a user sees

```
┌ Sidebar ┬──────────── Tab bar ────────────┬───────────────────────┐
│ Projects│                                 │ Files │ Changes │ Preview│  extension panel
│         │  CLI terminal, or the tab's     │                       │  (window level)
│         │  conversation view              │  tree / diff / file   │
│         │                  [map column]   │                       │
└─────────┴─────────────────────────────────┴───────────────────────┘
```

- **Extension panel.** A column at the right of the window, after the tab content and its conversation map column. **View → Show Extension Panel** turns it on, with a Command shortcut (PRD-20). A switcher at its top lists the panels of the turned-on extensions. The panel follows what the window shows: the selected tab, the active pane of a shown split, or the session selected in the sidebar when no tab shows. It works on that session's host and project folder.
- **Conversation view.** A per-tab alternative to the terminal, chosen with **View → Show Conversation View** / **Show Terminal** and the tab's right-click menu. The CLI keeps running in its terminal, which only stops being drawn. Plain terminals have no conversation view.
- **Settings → Extensions.** A page beside General, Appearance, Permissions, and Help, listing each extension with its switch, what it may access (its permissions), and its version.

These rules from existing requirements shape the layout:

| Rule | Consequence |
| --- | --- |
| TAB-07, DNR-04: nothing above a tab's terminal | The view switch lives in menus, not in a bar over the terminal. |
| DNR-01: the tab bar holds only terminals | Preview and diffs open in the panel, never as tabs. |
| DNR-15: splits have two panes | The panel is not a split pane. The split-view requirements gain a line that says so. |
| PRD-20, DNR-07: no window shortcuts on keys CLIs use | A web view gets keys only after it is clicked, and panel shortcuts use Command. |
| TAB-09: the terminal resizes only on a deliberate change | Showing or hiding the panel resizes the terminal once; switching panels or tabs never does. |

## Architecture

### Packages and manifest

An extension is a folder with `extension.json`, its web assets, and its strings. The first-party ones are bundled in `JustSessions.app/Contents/Resources/Extensions/<id>/`. Third-party ones later load from `~/Library/Application Support/dev.zichaoyang.justsessions/Extensions/<id>/`.

```json
{
  "id": "justsessions.files",
  "version": "1.0.0",
  "name": { "en": "Files", "zh-Hans": "文件" },
  "engines": { "justsessions": ">=1.3.0" },
  "contributes": {
    "panels": [{ "id": "files", "entry": "panel/index.html", "icon": "folder" }]
  },
  "permissions": ["workspace.read", "git"]
}
```

`contributes.conversationViews` declares a tab view such as the conversation view.

### Panel host

- **One web view per shown panel**, created the first time it shows and released after it stays hidden for a while. A hidden panel's page gets no events and the app runs no work for it, as the conversation map does (PERF-89). Panels are never an input of `EmbeddedTerminalView` or `TerminalInsetView`.
- **Content comes from a custom URL scheme**, `justsessions-extension://<id>/…`, through a `WKURLSchemeHandler` that serves only the extension's own files. There is no `file://` access.
- **No network by default.** A Content Security Policy with `connect-src 'none'` and a `WKContentRuleList` that blocks `http` and `https` loads keep PRD-02 true. An extension asks for `network` in its manifest to lift this. First-party extensions never ask.
- **Theme.** The app passes the theme palette as CSS custom properties, such as `--js-text`, `--js-surface`, `--js-accent`, and each CLI's hue, along with `color-scheme`, and updates them when the theme changes. First-party panels use only these variables, so the readable text colors that meet PRD-21 carry over.
- **Language.** `context.language` is `en` or `zh-Hans`. Each extension keeps its strings in `l10n/en.json` and `l10n/zh-Hans.json`. A check beside `make localization-check` fails when a first-party extension is missing a key in either language (PRD-07).

### Bridge API

The page sees `window.justsessions`. Every call is checked against the manifest's permissions on the Swift side. File paths are confined to the project folder, resolved on the host the session runs on.

```ts
interface JustSessions {
  context: { host: string; projectPath: string; tool?: string; sessionId?: string; language: string };
  onContextChange(handler: (context: JustSessions["context"]) => void): Disposable;

  fs: {                                   // "workspace.read"
    list(path: string): Promise<Entry[]>;
    read(path: string, options?: { maxBytes?: number }): Promise<{ data: Uint8Array; truncated: boolean }>;
    resourceURL(path: string): string;    // for <img src>, PDF, and relative links in HTML or Markdown
    watch(paths: string[], handler: (changed: string[]) => void): Disposable;
  };
  git: {                                  // "git"
    status(): Promise<GitStatus>;
    diff(options: { path?: string; staged?: boolean }): Promise<string>;
  };
  transcript: {                           // "transcript"
    entries(options?: { after?: number }): Promise<TranscriptEntry[]>;
    onAppend(handler: (entries: TranscriptEntry[]) => void): Disposable;
  };
  terminal: {                             // "terminal.input"
    activity(): Promise<"working" | "waiting" | "idle" | null>;
    onActivity(handler: (activity: string | null) => void): Disposable;
    sendText(text: string, options: { submit: boolean }): Promise<void>;
    show(): void;                         // back to the terminal
  };
  preview: { open(path: string): void };
  editor: { open(path: string, line?: number): void };   // the existing Open project in editors
}
```

### Host services

Each bridge area is a Swift service with one implementation for this Mac and one for SSH hosts. Extensions never see the difference.

| Service | This Mac | SSH host |
| --- | --- | --- |
| `ProjectFileSystem` | `FileManager`, FSEvents | Commands over the shared connection; polling while shown |
| `ProjectGit` | `git` from the login shell's `PATH` | `git` on the host |
| `LiveTranscript` | The session file, read incrementally as the map reads it | The session's local copy, kept fresh while a view shows (see [SSH](#ssh-hosts)) |
| `TerminalInput` | The tab's pseudo-terminal | The same: the tab's `ssh` and tmux carry it |

The proposed new folders are `Models/Extensions/`, `Services/Extensions/` (host, bridge, manifest, and permissions), `Services/Extensions/Workspace/ThisMac/` and `…/SSH/`, and `Views/Extensions/`. Web sources live in a top-level `Extensions/<id>/`, which a `make extensions` step builds into `Sources/JustSessions/Resources/Extensions/`. `Package.swift` copies that folder, and PRD-09's launch check confirms it in the packaged app. Node is already required by `make verify` for the website tests.

### Structured tool calls

Today every reader reduces a tool call to one line of text (`ToolCallSummary`, `TranscriptEntry.Content.toolCalls([String])`). That is not enough for tool cards or for the Changes extension's session view. The proposal is:

- Add a structured tool call to `TranscriptEntry`: name, input as JSON, output text (with a size cap), status, and, for edits, the file changes it made (path, plus old and new text or a patch).
- Each of the six readers maps its own records. Examples: Claude Code's `tool_use` and `tool_result` (Edit, MultiEdit, Write), and Codex's `function_call`, `custom_tool_call` (`apply_patch`), and `function_call_output`. Pi, OpenCode, Kiro CLI, and Antigravity are mapped from their own formats, each confirmed against real files.
- The one-line summaries are derived from the structured call. The reader, map, and message search keep their current output.
- Rerun the reader and outline measurements (PERF-60, PERF-67, PERF-68, PERF-90) and the message search ones (PERF-66, PERF-70, PERF-71). Tool outputs stay out of the search index unless measured.

## The four extensions

### Conversation view

- Shows the tab's linked session from its session file as messages reach it. CLIs write whole messages, so the view updates per message, not per token.
- Draws Markdown with code highlighting, images, collapsible tool cards with input and output, edit cards with their diffs, and [OpenUI](#openui-generated-ui) blocks.
- **Message box:** sends its text into the CLI as one bracketed paste followed by Return, the same path as typing, on this Mac and over SSH. While the CLI works, the CLI itself decides whether to queue the message.
- **While the CLI waits for you** (activity `needsInput`), the view shows its reason and a **Show terminal** button. There are no approve or deny buttons.
- A tab not linked yet shows *Not linked yet*, as the map does.

### Files

- In a Git work tree: `git ls-files -z --cached --others --exclude-standard`, so `.gitignore` applies and a large repository lists quickly. Elsewhere: one directory level at a time. Ignored and hidden files show on request.
- **Click** opens the file in Preview. **Double-click** opens it in the editor chosen for file links (`FileLinkClickChoice`). **Dragging** onto a tab types its path, through the existing file drop, which already copies to SSH hosts. The right-click menu offers Copy Path, and Reveal in Finder on this Mac.
- Git status marks come from the Changes service. The tree updates from FSEvents on this Mac and by polling on SSH hosts.

### Changes

- **Working tree:** `git status --porcelain=v2 -z`, then `git diff` per file, with a size cap and binary detection. Staged and unstaged changes are listed apart, and untracked files show as added. Unified and side-by-side layouts.
- **This session:** edits from the structured tool calls, grouped by turn. This works without Git.
- **Comment on a line:** writes `path:line` and the comment into the conversation view's message box. Nothing is sent until you send it.
- On this Mac, `git` comes from the login shell's `PATH`. The app never runs `/usr/bin/git` when `xcode-select -p` fails, since that stub opens the Command Line Tools installer.

### Preview

- Images, PDF (WebKit), Markdown (rendered, with relative images through `resourceURL`), HTML (in a sandboxed frame, scripts off unless allowed), and source code with highlighting. Other kinds offer **Open in default app** on this Mac.
- Size caps per kind are chosen by measurement. A capped file says so.
- **Dev server:** a URL field for `localhost` ports. On an SSH host it offers the host's listening ports (`RemoteListeningPorts`) and starts **Forward a port…** for the chosen one.
- **⌘-clicking a file link** in a tab gains a **Preview** choice in Settings → General → Tabs. This choice also covers paths on SSH hosts, which ⌘-click never opens today (`TerminalLinkOpener`).

## OpenUI generated UI

[OpenUI](https://github.com/thesysdev/openui) (MIT) is Thesys's open-source generative UI project. A model writes OpenUI Lang, a compact, line-oriented language for UI, and a renderer draws it:

- **Library and prompt.** A component library is defined with `createLibrary` and `defineComponent` (`@openuidev/react-lang`, props as Zod schemas). `generateSystemPrompt` from `@openuidev/lang-core` turns it into the instructions the model needs: syntax rules, component signatures, and actions.
- **Renderer.** `<Renderer library={…} response={text} isStreaming={…} />` from `@openuidev/react-lang`. Vue, Svelte, and Angular runtimes and a no-build browser bundle that includes React also exist.
- **Actions.** `useTriggerAction()` sends text as the user's next turn.
- **Local only.** The cloud Gateway (`api.thesys.dev`, `THESYS_API_KEY`) is optional. Prompt generation and rendering run locally.

How it fits JustSessions:

1. **The agent must receive the generated prompt.** The CLIs write Markdown by default. A turned-on **Let agents show generated UI** setting gives the CLI the component prompt at launch, without editing its configuration (PRD-01). Pi's `--extension` is the precedent for adding something at launch (LIV-06, SSH-91). The agent then writes OpenUI Lang in a fenced `openui` block. The conversation view renders the block, and the terminal shows it as code.
   - The launch-time mechanism is chosen per CLI and confirmed before it ships, such as Claude Code's `--append-system-prompt` or an Agent Skill passed at launch.
   - A CLI with no launch-time mechanism doesn't offer the setting.
   - A later option is a `show_ui` MCP tool whose input is OpenUI Lang. The terminal would then show one tool line instead of the code, but the tool's server would have to run where the CLI runs, including on SSH hosts.
2. **A small library keeps the cost down.** The prompt is added to every session that uses it, so the library stays small: Card, Table, Metric, Chart, List, Tabs, Steps, Button, and form inputs. Each is styled only with the app's theme variables.
   - There is no `Query` or `Mutation`: the app has no data backend for them.
   - The setting's help popover says that it costs tokens and changes how the agent answers.
3. **Actions become messages.** `triggerAction(text)` goes through `terminal.sendText` as the next prompt and shows as your message. While the CLI waits on an approval, actions are disabled.
4. **No streaming.** Messages arrive whole, so blocks render with `isStreaming` false.
5. **Bundled, never fetched.** React and the OpenUI packages are built into the extension, and their licenses are added to the app's notices.

Still unverified, to check before the conversation view's OpenUI phase starts:

- The OpenUI docs on theming (`defining-components`), forms and actions (`interactivity`, `actions`), and the bundle size.

## SSH hosts

An extension calls the same API for this Mac and SSH hosts. The implementation differs in these ways:

| # | Difference | Plan |
| --- | --- | --- |
| 1 | Every read is a command on the host. Commands share one connection (SSH-22), but each still starts the host's login shell (SSH-24): about 110–130 ms per command on the test VM (PERF-87), plus the network's round trip. | Batch work into one command, such as one directory level with its Git marks. Cache per host and path. If measurements show it too slow, keep one helper shell per host open while a panel shows. |
| 2 | There are no file events. | Poll `git status` and the expanded folders every 3 seconds, one poll per host, only while a panel shows. There is no poll while the panel is hidden or the host is disconnected. Same shape as PERF-87. |
| 3 | The conversation's local copy is refreshed only every 5 minutes (SSH-104), far too slow for a conversation view. | While a conversation view shows an SSH session, copy that session's files every 3 seconds through the shared connection. `rsync` sends only the new end of an appended JSONL file. OpenCode's database snapshot is heavier and copies less often. The map benefits too. SSH-104 changes. |
| 4 | `RemoteHostCommandRunner` returns text, and previews need bytes. | Add a variant that returns data up to a byte cap. Cache by host, path, size, and modification date in `~/Library/Caches` (0700 folder, 0600 files, no data protection class: DNR-34). |
| 5 | HTML and Markdown link to files beside them. | The scheme handler fetches each linked file from the host when the page asks for it. |
| 6 | Hosts run different shells and systems. | Quote as SSH-25 does. Wrap anything beyond simple commands in `sh -c`, because the login shell may be fish (SSH-26). Use no GNU-only flags, such as `find -printf` or `stat -c`. Test on the Ubuntu VM and on a macOS account, as AGENTS.md asks. |
| 7 | Paths must stay inside the project folder. | Resolve them on the host (`cd` and `pwd -P`) before reading. |
| 8 | A host can be disconnected (SSH-101), need **Connect…**, or be unreachable. | Panels run nothing on a disconnected host and show **Disconnected** with **Connect**. A host that needs Connect… asks for it. An unreachable host fails at once (`SSHHostReachability`) and retries when the user asks. A Windows host, which `WindowsHostProbe` already recognizes, gets no panels. |
| 9 | Tools can be missing. | Without `git`, Files lists folders directly and Changes shows only the session's edits. **Check this host…** adds `git` to its lookup. |
| 10 | Dev servers run on the host. | Use the existing port forwards (SSH-95, SSH-96). |

The message box and activity work the same way on SSH, since they go through the tab's terminal and the activity tmux already relays (SSH-84). Most of the extra SSH work is items 1–3.

## Requirements to update

| Line | Change |
| --- | --- |
| PRD-01 | Add: the conversation view is an optional way to read and type, and the CLI's interface keeps running behind it, one menu item away. |
| PRD-02 | Add: extensions have no network unless they ask for it, and first-party extensions never do. |
| DNR-11 | Add: the reason for removing the web view was Turnstile, which never finished in the app's web view. It does not apply to extension panels. |
| SSH-104 | Change: a shown conversation view keeps its session's copy fresh (SSH item 3). |
| Split view | Add a line that the extension panel is not a split pane (DNR-15). |
| Performance budgets | Add budgets: a hidden panel does nothing, web view memory per panel, Files on a repository of 100,000 files, the SSH poll's cost, and the transcript measurements after structured tool calls. |
| New `requirements/app/extensions.md` | `EXT-` lines as each phase lands, starting with: every extension off by default, turned on in Settings → Extensions. |
| `make verify` | The launch check starts with every extension off, as it does with tab reopening. |
| [Source layout](source-layout.md) | Add the new folders. |

## Phases

Each phase can be released on its own:

1. **Panel host.** Manifest loading, the bridge with permissions, Settings → Extensions, theme and language variables, and an internal test extension. Includes confirming that a notarized build with a `WKWebView` needs no `allow-jit` entitlement.
2. **Files and Preview**, on this Mac and on SSH hosts (SSH items 1, 2, and 4–9).
3. **Changes:** Git first, then structured tool calls and the session's edits.
4. **Conversation view:** read-only first, then the message box, then SSH freshness (SSH item 3).
5. **OpenUI** in the conversation view, starting with one CLI.
6. **Third-party extensions** from the folder in Application Support, with a guide to writing one.

## Risks

- **JIT.** `WKWebView` runs web content in a separate process (WWDC 2017 session 220), so the app should not need `com.apple.security.cs.allow-jit`. This must be confirmed on a notarized build, because Apple's documentation doesn't say so.
- **Not live per token.** The conversation view updates per message, never per token.
- **Approvals stay in the terminal.** Answering them in the view would mean driving each CLI through its structured protocol in place of its interface, which PRD-01 rules out.
- **Generated UI depends on the agent.** OpenUI blocks appear only when the agent follows the prompt, and every session that turns it on pays the prompt's tokens.
- **Memory.** Web view memory adds up with several windows. Phase 1 measures it before more panels are built.

## References

- [thesysdev/openui](https://github.com/thesysdev/openui), and its docs on [UI generation](https://github.com/thesysdev/openui/blob/main/docs/content/docs/build-agents/ui-generation.mdx), [system prompts](https://github.com/thesysdev/openui/blob/main/docs/content/docs/openui-lang/system-prompts.mdx), and the [quickstart](https://github.com/thesysdev/openui/blob/main/docs/content/docs/openui-lang/quickstart.mdx)
- [VS Code: Our approach to extensibility](https://vscode-docs1.readthedocs.io/en/stable/extensions/our-approach/)
- [Claude Code desktop](https://code.claude.com/docs/en/desktop), for the diff, file, and preview panes this follows
- [WWDC 2017 session 220](https://nonstrict.eu/wwdcindex/wwdc2017/220/), on WKWebView process isolation
- [Apple: com.apple.security.cs.allow-jit](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.allow-jit.md)
