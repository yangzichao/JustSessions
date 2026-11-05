# Removed on purpose

[Back to requirements](README.md)

Things the project tried or had, then removed or rejected. Bringing one back needs a decision that answers the original reason, not just a pull request.

## UI

| ID | Don't bring back | Why | Origin |
| --- | --- | --- | --- |
| DNR-01 | A Preview tab in the tab bar. | Selecting a session shows its preview; the tab bar holds only terminals. | `b4c6d11` |
| DNR-02 | A list of open terminals inside the Projects view. | It repeated the tab bar and pushed projects down. Open tabs is its own sidebar view. | `478fdba`, `1c369eb` |
| DNR-03 | Inline Resume and Branch buttons on list rows. | Actions live in the row's ⋯ and right-click menus; double-click resumes. | `d5c9dfc` |
| DNR-04 | A header above each tab's terminal, and its Copy selection button. | They repeated the tab's title and ⌘C. | `90b2bd0`, `9dd8461` |
| DNR-05 | A toggle that stops the CLI from receiving the mouse. | The CLI always receives mouse input. | `715a0c2` |
| DNR-06 | ⌃⌘S for the sidebar. | ⌘B, as in code editors; a menu command takes one shortcut. | `ca9e282` |
| DNR-07 | Window-level shortcuts on keys CLIs use (Escape, arrows, ⌘⌫, Control-B). | They steal keys from the embedded CLI, such as Claude Code's Escape. | Project decision, 24 September 2026 |
| DNR-08 | System tooltips on tabs and group labels. | The hover card replaces them; both would show. | `08525c2` |
| DNR-09 | Ellipses in tab titles, and the tab bar's overlay scroller. | Titles fade; the scroller drew over titles. | `26a8b33`, `1f6545d` |
| DNR-10 | Settings and Help as separate windows. | They slipped behind the workspace window; they are sheets. | `2c3e9c9` |
| DNR-11 | An in-app feedback form or Turnstile web view. | Turnstile never finished in the app's web view; feedback opens the website form. | `30f1b46` |
| DNR-12 | Subagent rows shown by default. | Hidden until turned on in Settings → General. | `23c4377` |
| DNR-13 | System secondary and tertiary text styles in Views, and translucent selected-row fills. | They fell below 4.5:1 on theme surfaces and P3 displays. A contract test enforces the first. | `16246c3` |
| DNR-14 | Removing a project for good. | Projects are archived and can be restored. | `d8e8b4a` |
| DNR-15 | Splits with more than two panes, or a grid of panes. | Split view follows Chrome's two-tab model (SPL-01–13); a pane grid would replace that model, not extend it. *Changed 31 October 2026: a split's two views can stack, one above the other (SPL-18). It stays one pair of tabs, ordered by the tab bar, with one resize area, so the model is unchanged; a terminal often wants a full-width pane below another, which Chrome's pages don't (PRD-25).* | Project decision, 11 October 2026; feature request, 31 October 2026 |

## Code and build

| ID | Don't bring back | Why | Origin |
| --- | --- | --- | --- |
| DNR-30 | The project's earlier names, legacy update paths, extra release archives, `build-<sha>` release tags, or compatibility shims for old installs. | Sparkle on `v*` tags is the only update path; the codebase keeps no old names, in code, tests, scripts, or docs. | `3daec6f`, `2054475` |
| DNR-31 | Per-tool capability flags and "unsupported" branches for preview, deletion, or SSH. | Every supported CLI has all three. | `4197645` |
| DNR-32 | A lazy stack, `.scrollPosition(id:)`, or `.scrollTargetLayout()` in the transcript. | The lazy stack froze the window; scroll tracking doubled each scroll step. | `5ae6c53`, `ab02d9e` |
| DNR-33 | SwiftTerm's Metal renderer, without a new measurement. | No CPU saving, dropped frames, 150–200 ms main-thread stalls, and hidden tabs kept drawing. | `1533250` |
| DNR-34 | A data protection class on cache files. | On macOS 26.5.1 the same user couldn't read them back, so every refresh parsed every file. | `a7d1b6d` |
| DNR-35 | Adding `chat` after a Kiro CLI start command. | Kiro CLI took the second `chat` as the first prompt. | `3330273` |
| DNR-36 | Test settings suites named like an app's, which leave plists in `~/Library/Preferences`. | Each test run left about a thousand files; suites now live in a temporary folder. | `0206e12` |
