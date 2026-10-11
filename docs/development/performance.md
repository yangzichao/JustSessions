# Performance

[Back to JustSessions](../../README.md) · [Build and release](build-and-release.md) · [Source layout](source-layout.md)

This page tracks known responsiveness problems, the evidence for each, and what has been done about it. Update an item's status when its pull request merges, and add new findings with their measurements.

## Baseline: v1.0.8, 7 October 2026

A dev build of `083d92e` (v1.0.8) was profiled for 27 minutes of ordinary use: searching, scrolling the transcript of a session that wasn't running, switching tabs, and running CLIs in terminals. The recording was made in 13 two-minute chunks.

| Measure | Result |
| --- | --- |
| Main thread busy | 269 s in total; 7–37% of each chunk, 44 s of 120 s in the worst |
| Freezes (Hangs instrument) | 18, from 257 to 523 ms; 15 of them between 18:33 and 18:36, while reading and searching a transcript |
| Background CPU | 1–5 s per chunk; one 6 s burst of message-search indexing used 2.4 cores |

The main thread's 269 busy seconds went to two kinds of work. **Terminals** are the largest steady cost; **SwiftUI** causes the freezes.

| Work | Share | What it is |
| --- | --- | --- |
| Terminal drawing | 43% | SwiftTerm drawing rows on the CPU. In chunks spent mostly in terminals, it was 57–69% of the busy time, at up to 200 ms per second. Parsing the same output took about 12 ms per second. |
| Terminal output parsing | 13% | SwiftTerm reading the CLIs' output. |
| SwiftUI updates | 13% | Re-rendering the window's one view tree. |
| Other layout and drawing | 11% | The rest of each display cycle. |
| Hover, hit testing, and cursor updates | 8% | Run on mouse moves, through every view in the transcript: 28% of the busy time in the worst chunk. |
| Accessibility | 5% | Includes SwiftUI walking the whole responder tree to find the accessibility focus. |
| Transcript text bodies | 1% | 1.3 s in one chunk, copying text to search it with no search active. |

The accessibility walk was most of each freeze. SwiftUI only does it while an accessibility client is connected, such as Raycast, a window manager, a password manager, or VoiceOver. cmux measured Raycast querying a window about [32 times a second](https://github.com/manaflow-ai/cmux/issues/2985).

The tree is large because the transcript lays out every loaded entry, up to `TranscriptPagingModel.maximumRetainedPageCount` pages. It uses a plain `VStack` on purpose; see `TranscriptScrollView.transcriptEntries`.

## Terminal engines: Ghostty and SwiftTerm

`TerminalEngineMeasurements` runs the same output through a tab of each engine, on 9 October 2026. A script started with the tab's own `startProcess` writes the output to the tab's pseudo-terminal, so it reaches each terminal as a CLI's does. The test window is ordered front, so both engines draw.

**Method:**
- **Machine:** Apple M4 Pro, 12 cores (8 performance, 4 efficiency), 24 GB, macOS 26.6.1, the built-in Liquid Retina XDR display.
- **Build:** commit `9998098`, built by `swift test -c release` with Xcode 27.0 (Swift 6.4, macOS 27.0 SDK), not the release's SDK. SwiftTerm is the 1.15.0 fork, drawing on the CPU; Ghostty is libghostty-spm `2.2.2026100901`.
- **Runs:** three of each, alternating which engine goes first. Each result is the median, with the lowest and highest in brackets. Each memory run had a process of its own.
- **Load:** the machine was busy, so absolute CPU figures are noisy; compare the engines. Blender used 60–120% of a core and 13 GB throughout, a running copy of the app 30–80%, and WindowServer 35–48%, with bursts from Spotlight and media analysis. The load average was 5–9.
- **CPU:** process CPU from `getrusage`, as a percentage of one core. The scripts writing the output are child processes, so they don't count. Main-thread CPU comes from `thread_info`.
- **Gaps:** `MainThreadPerfHeartbeat` ticks every 20 ms. On this machine its longest gap was 25–30 ms even with the main thread almost idle, so a gap under about 30 ms is no hitch.
- **Frames:** for SwiftTerm, calls to its view's `draw(_:)`. For Ghostty, each frame its renderer hands to its layer, as the layer's new contents.

The workloads:
1. **Repaint:** 8 rows rewritten 30 times a second for 5 s, with a spinner, as in `TerminalVisibilityMeasurements`. One tab, shown.
2. **Bulk:** 20 MB in 175,920 log lines, colored, every fifth in truecolor and about every seventh with CJK text, written by `cat`. One tab, shown. Timed until the terminal has parsed all of it and its screen shows the last line.
3. **Hidden tabs:** the repaint in 5 or 10 tabs, one shown, the rest hidden through `setWorkspaceActive(false)`.
4. **Memory:** before any tab, with 10 idle tabs, and after the bulk stream in all 10 tabs. A tab's share is a tenth of the change.

**Repaint, one tab:**

| Measure | Ghostty | SwiftTerm |
| --- | --- | --- |
| Process CPU, % of one core | 4.4 (3.9–4.8) | 15.3 (13.4–15.8) |
| Main-thread CPU, % of one core | 1.2 (1.1–1.2) | 14.8 (12.9–15.3) |
| Longest main-thread gap | 28.7 ms (28.5–31.8) | 31.6 ms (28.5–41.0) |
| Frames drawn in 5 s | 151 | 149 (147–149) |

**Bulk stream, one tab:**

| Measure | Ghostty | SwiftTerm |
| --- | --- | --- |
| Time until parsed and on screen | 0.21 s (0.20–0.22) | 0.79 s (0.77–0.80) |
| Process CPU, % of one core | 352 (343–366) | 123 (122–123) |
| Process CPU time, from the medians | 0.74 s | 0.97 s |
| Main-thread CPU, % of one core | 65 (61–65) | 98 (98–99) |
| Longest main-thread gap | 26.5 ms (26.0–27.5) | 31.3 ms (30.0–32.4) |
| Frames drawn | 379 (291–381) | 35 (34–35) |

Ghostty parsed the stream about four times as fast, across several threads. It handed its layer more frames than a display can show in that time; how many reached the screen is unconfirmed.

**Repaint, one tab shown and the rest hidden:**

| Tabs | Process CPU, Ghostty | Process CPU, SwiftTerm | Main thread, Ghostty | Main thread, SwiftTerm | Longest gap, Ghostty | Longest gap, SwiftTerm |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 4.4% | 15.3% | 1.2% | 14.8% | 28.7 ms | 31.6 ms |
| 5 | 6.1% (5.4–6.8) | 18.9% (16.6–20.0) | 1.5% | 17.5% | 29.3 ms | 29.8 ms |
| 10 | 7.1% (6.7–7.3) | 17.2% (16.8–20.5) | 1.8% | 15.3% | 30.0 ms | 27.7 ms |

Each hidden Ghostty tab added about 0.3% of a core, mostly off the main thread. Hidden SwiftTerm tabs added 2–4% in all, more with 5 tabs than with 10, so the load's noise is as large as their cost. Both engines drew 149–151 frames for the shown tab.

**Memory, in MB:** the medians of three runs. The runs differed by at most 2.3 MB per tab, and for SwiftTerm by under 0.5 MB.

| Measure | Ghostty | SwiftTerm, 500 lines | SwiftTerm, 10,000 lines, shipped |
| --- | --- | --- | --- |
| Footprint before any tab | 59.8 | 59.9 | 60.0 |
| Footprint with 10 idle tabs | 212.5 | 82.6 | 83.4 |
| Footprint per idle tab | 15.3 | 2.3 | 2.3 |
| Footprint after the stream in all 10 tabs | 285.4 | 77.8 | 384.8 |
| Footprint added per full tab | 7.4 | −0.5 | 30.1 |
| Resident memory added per full tab | 55.1 | 8.4 | 39.2 |
| Scrollback kept, rows × columns | 46,341 × 125 | 540 × 115 | 10,040 × 115 |

The footprint is what Activity Monitor's Memory column shows. Read the table with these points in mind:
- **An idle Ghostty tab** costs about 15 MB, nearly all of it graphics memory: the surfaces it draws into, which hidden tabs keep too. With 10 idle tabs, `vmmap` showed 98 MB of "owned unmapped (graphics)", 30 MB of IOSurface, and 7 MB of IOAccelerator memory.
- **Ghostty's scrollback isn't in the footprint.** `vmmap` shows its terminal pages as "Memory Tag 240": with 10 full tabs, 477 MB resident but only 4 MB dirty, and the footprint is `vmmap`'s dirty total. Resident memory gives the real cost, about 55 MB per full tab. Whether macOS can reclaim those pages without losing scrollback is unconfirmed.
- **For SwiftTerm, the footprint is the cost.** Its resident figure also counts memory the allocator freed and kept.
- **One run per process.** In a process that had already run the same case, the footprint counted 0–22 MB per full SwiftTerm tab with 10,000 lines instead of 30: memory the process freed and then reused wasn't counted again.

**Scrollback differs by engine.** A Ghostty tab keeps far more scrollback than SwiftTerm does by default: 46,341 rows here, against SwiftTerm's 500 lines. Full, it holds about 55 MB, against well under 1 MB for SwiftTerm's 500 lines, or 30 MB for 10,000. A SwiftTerm tab keeps 10,000 lines (`SelectableTerminalView.scrollbackLineCount`), so terminal Find reaches that far back. Only the main screen keeps scrollback, so a CLI in tmux, which draws on the alternate screen, adds none. The app sets no limit for Ghostty, so Ghostty's default `scrollback-limit` applies. Upstream documents it as 10,000,000 bytes, so how Ghostty counts it against these 55 MB is unconfirmed.

**Profile:** one 5-second `sample` of the repaint for each engine.
- **SwiftTerm:** the main thread was busy in 721 of 3,675 samples, 20%. Parsing the output (`feed`) took 12 of them, and Core Animation's commit, drawing the view, 693. No other thread did measurable work. The drawing went to:
  - 251 samples in `NSView` drawing, where SwiftTerm's `drawTerminalContents` records each row's text;
  - 417 in updating the layer's backing store, which replays those commands. 316 of them rasterized glyphs into the 16-bit RGBA backing store this XDR display gets (`RGBAf16_mark_constmask`, `vCGCompositeConstMask_ARGB16F_vec`).
- **Ghostty:** the main thread was busy in 28 of 3,459 samples, under 1%: committing the layer's new contents, and handing output on. Ghostty's renderer thread took 29 samples, Metal's command queue 21, Ghostty's output parsing 6, and reading the pseudo-terminal 5. All threads together were busy in 94 samples, against SwiftTerm's 726.

**The libghostty-spm fork, 11 October 2026.** The pin moved to the fork that passes on Ghostty's search counts; see [libghostty](build-and-release.md#libghostty). The fork adds cases to the wrapper's action handler that run only during a search, and downloads the same `libghostty.a`. `TerminalEngineMeasurements` ran on the base (`f8d8d61`, upstream `2.2.2026100901`) and on the fork (`09d84fd`), alternating base, fork, base, fork.

**Method:**
- **Machine:** Apple M4 Max, 14 cores (10 performance, 4 efficiency), 36 GB, macOS 27.0.1.
- **Build:** release build from `swift test -c release`.
- **Load:** other builds were running. The load average was 3–10.
- **Runs:** each figure below is the median of the test's three runs in that round. Memory is one run per round, each in a process of its own.

| Ghostty | Base, round 1 / 2 | Fork, round 1 / 2 |
| --- | --- | --- |
| Repaint, 1 tab: process CPU | 5.1% / 5.1% | 5.8% / 5.8% |
| Repaint, 1 tab: main thread | 1.2% / 1.3% | 1.5% / 1.4% |
| Repaint, 1 tab: longest main-thread gap | 28.1 / 28.7 ms | 29.9 / 28.5 ms |
| Repaint, 5 tabs, 1 shown: process CPU | 8.3% / 7.5% | 5.6% / 7.3% |
| Repaint, 10 tabs, 1 shown: process CPU | 9.3% / 9.9% | 10.0% / 9.2% |
| Bulk 20 MB: time | 0.20 / 0.20 s | 0.20 / 0.19 s |
| Bulk 20 MB: process CPU | 345% / 342% | 339% / 353% |
| Footprint per idle tab | 25.6 / 25.6 MB | 25.6 / 25.2 MB |
| Footprint added per full tab | 7.1 / 7.1 MB | 7.9 / 8.6 MB |
| Resident memory added per full tab | 54.1 / 54.1 MB | 49.3 / 55.0 MB |

No difference stands out from the load's noise:
- **CPU:** with one tab, the fork used 0.7 points more in both rounds. With five tabs it used less.
- **Memory:** the fork's footprint per full tab was 0.8–1.5 MB higher. That is within the 2.3 MB that separate runs differed by in the memory table above.
- **Frames:** every repaint drew 149–150 frames.

This Mac's figures differ from the M4 Pro's above, for example 25.6 MB per idle tab against 15.3 MB, so compare the two columns, not the two machines.

## Work items

| # | Item | Status |
| --- | --- | --- |
| 1 | [Timestamp parsing](#1-timestamp-parsing) | Done: #46 |
| 2 | [Transcript text searches only during Find](#2-transcript-text-searches-only-during-find) | Done: #46 |
| 3 | [Fast `AttributedString` to `String` conversion](#3-fast-attributedstring-to-string-conversion) | Done: #46 |
| 4 | [One position marker view per transcript entry](#4-one-position-marker-view-per-transcript-entry) | Done: issue #53 |
| 5 | [Text selection on very long blocks](#5-text-selection-on-very-long-blocks) | Measured, no change: issue #54 |
| 6 | [Terminal drawing](#6-terminal-drawing) | Done for Ghostty, the engine you can choose in Settings: libghostty PR. SwiftTerm's Metal drawing measured and not turned on: issue #52 |
| 7 | [The search context changes on every transcript update](#7-the-search-context-changes-on-every-transcript-update) | Done: scrolling PR |
| 8 | [Scrolling re-rendered every transcript entry](#8-scrolling-re-rendered-every-transcript-entry) | Done: scrolling PR |
| 9 | [SwiftUI's scroll position tracking](#9-swiftuis-scroll-position-tracking) | Done: issue #55 |
| 10 | [Message search decoded every image](#10-message-search-decoded-every-image) | Done: issue #59 |
| 11 | [Codex's compacted records are parsed in full](#11-codexs-compacted-records-are-parsed-in-full) | To investigate |
| 12 | [Every reader decoded its own images](#12-every-reader-decoded-its-own-images) | Done: issue #62 |
| 13 | [Each OpenCode page read every message's data](#13-each-opencode-page-read-every-messages-data) | Done: issue #60 |
| 14 | [A CLI activity change updates only the rows in view](#14-a-cli-activity-change-updates-only-the-rows-in-view) | Measured, no change: issue #61 |
| 15 | [Terminals in minimized windows drew as if in sight](#15-terminals-in-minimized-windows-drew-as-if-in-sight) | Done: issue #63 |
| 16 | [Typing beside flooding terminals](#16-typing-beside-flooding-terminals) | Measured, no change: issue #58 |
| 17 | [SSH connections during a remote refresh](#17-ssh-connections-during-a-remote-refresh) | Changed, not measured live: issue #64 |
| 18 | [Workspace windows repeated discovery and message indexing](#18-workspace-windows-repeated-discovery-and-message-indexing) | Done: issue #57 |
| 19 | [The working spinner re-rendered the window 30 times a second](#19-the-working-spinner-re-rendered-the-window-30-times-a-second) | Done: idle render loop PR |
| 20 | [The notification bell's list on each sidebar redraw](#20-the-notification-bells-list-on-each-sidebar-redraw) | Measured, no change: issue #176 |

### 1. Timestamp parsing

**Evidence:** the 14 s indexing burst spent 2.9 s in `ISO8601DateFormatter`, which parses through ICU. Its two shared formatters sat behind one lock, so the indexer's parallel readers also waited for each other.

**Change:** `ISO8601TimestampParser` uses `Date.ISO8601FormatStyle`. In a benchmark of 200,000 timestamps it took 0.52 µs each, against 28 µs, and as a value it needs no lock. On 1,380 timestamps sampled from local Claude, Codex, Gemini, and pi sessions, it gave the same dates. On other inputs:

- **Finer fractions:** it keeps micro- and nanoseconds, which the formatter cut to milliseconds.
- **A leap second (`:60`):** it accepts it, which the formatter didn't.
- **A leading space:** it rejects it, which the formatter accepted. No CLI writes either form.

### 2. Transcript text searches only during Find

**Evidence:** `TranscriptSearchableText` copied its whole text into a `String` and searched it on every body evaluation, even with no query. It also read the whole environment with `@Environment(\.self)`, so any environment change re-ran it ([objc.io](https://talk.objc.io/episodes/S01E409-environment-preference-updates)).

**Change:** without a query, the body returns plain `Text` straight away. Only the view that draws highlighted matches reads the whole environment, which it needs to resolve theme colors.

### 3. Fast `AttributedString` to `String` conversion

**Evidence:** the indexing burst spent 1.9 s in the standard library's generic `String.init`, reading an `AttributedString` one character at a time. The cause is the SDK, not the code:

- Built with the macOS 26.5 SDK, as the release workflow's `macos-latest` runner builds, `String(text.characters)` compiles to the generic `String.init`.
- Built with Xcode 27's SDK, it calls Foundation's own conversion.
- `String(text.characters[...])` calls Foundation's conversion with either SDK.

On 10,163 text blocks from real Claude replies, the 26.5 SDK build took 348 ms the first way and 3.5 ms the second, with identical results. The v1.0.8 release binary calls the generic initializer in:
- `PreparedTranscriptMarkdown`, which prepares every transcript page;
- the search segments;
- `TranscriptSearchableText`;
- search highlighting;
- the Markdown parser's code blocks.

**Change:** these call sites now use `plainText`, which converts through the slice. Search highlighting also stops converting the text before each run again, which made it quadratic in the number of runs.

The Markdown parse itself stays. The search index stores the text as the reader displays it, block by block, so it needs the parsed blocks.

### 4. One position marker view per transcript entry

**Evidence:** each transcript entry has a `TranscriptEntryPositionMarker` background, an `NSViewRepresentable` that records the reading position. Each one adds two AppKit views, the marker and SwiftUI's host for it, and the profile shows them visited by:
- the accessibility focus walk;
- hit testing on every mouse move;
- AppKit's tracking-area updates.

In `TranscriptInteractionMeasurements`, after item 8, removing the markers takes the median scroll step from 9.7 to 4.8 ms with 240 entries, and from 34 to 17 ms with 640. It takes 200 hit tests from 494 to 417 ms. Those runs also skip the reader's own scroll handling, such as recording the reading position, so not all of the difference is the views.

**Change:** the entries' `Layout` records their ordered frames as it places them, and one AppKit observer converts those stack-local frames to scroll-view coordinates. A scroll update binary-searches the ordered frames instead of scanning every entry. Direct entry lookup remains constant-time for restoration, paging, and Find. The layout hands changed frames to a pending restoration immediately, preserving the same-pass correction when a page loads above.

`TranscriptInteractionMeasurements`, release build, median of three runs each. Every metric resets to an explicit viewport first: scrolling starts at the top; hit testing, Find, and lookup start at the midpoint. Position lookup measures 1,000 searches for the first visible entry through the same type-agnostic harness adapter on both implementations:

| Entries and accessibility | AppKit views | Scroll p50 / p95 / worst | 200 hit tests | Open Find | 1,000 position lookups |
| --- | --- | --- | --- | --- | --- |
| 240, off | 2,082 → 1,604 | 5.5 / 6.6 / 9.9 → 4.0 / 5.1 / 5.4 ms | 508 → 440 ms | 59.8 → 56.1 ms | 17.0 → 0.2 ms |
| 240, on | 2,082 → 1,604 | 5.4 / 6.8 / 7.3 → 4.1 / 5.2 / 5.6 ms | 511 → 438 ms | 116 → 103 ms | 17.0 → 0.2 ms |
| 640, off | 5,482 → 4,204 | 17.4 / 20.1 / 21.7 → 13.6 / 15.4 / 16.0 ms | 1,462 → 1,319 ms | 73.4 → 91.1 ms | 43.6 → 0.2 ms |
| 640, on | 5,482 → 4,204 | 18.2 / 20.0 / 20.4 → 14.9 / 17.2 / 18.0 ms | 1,467 → 1,283 ms | 317 → 310 ms | 44.3 → 0.2 ms |

Opening Find with 640 entries and accessibility off reproducibly regressed from 73.4 to 91.1 ms. A supplemental investigation with temporary instrumentation, which the committed harness does not include, put the extra time in synchronous SwiftUI layout during the opening turn rather than in the geometry layout: `TranscriptEntryGeometryLayout` did not place entries during that update, so rebuilding its registry is not the cause. The likely cost is the `GeometryReader` wrapper that supplies an exact transcript width to the custom layout; removing it made full-width and readable-width layout incorrect, and no small safe replacement was found. The other three Find configurations were unchanged or faster.

**Method:** Apple M4 Pro, 24 GB, macOS 26.6.1, Xcode 27.0 (Swift 6.4, macOS 27.0 SDK). The baseline was commit `895744b` with only the harness from `95ed3dd` copied over; after was `95ed3dd`. Reproduction commands:

```sh
git show 95ed3dd:Tests/JustSessionsTests/Performance/TranscriptInteractionMeasurements.swift > /tmp/issue-53-fair/TranscriptInteractionMeasurements.swift
git switch --detach 895744b
cp /tmp/issue-53-fair/TranscriptInteractionMeasurements.swift Tests/JustSessionsTests/Performance/TranscriptInteractionMeasurements.swift
for run in 1 2 3; do JUSTSESSIONS_PERF=1 swift test -c release --filter TranscriptInteractionMeasurements; done
git reset --hard 895744b
git switch issue-53-transcript-marker-geometry
for run in 1 2 3; do JUSTSESSIONS_PERF=1 swift test -c release --filter TranscriptInteractionMeasurements; done
```

Raw output is in `/tmp/issue-53-fair/baseline.txt` and `/tmp/issue-53-fair/after.txt`. The machine was not isolated; the first 240-entry baseline run was slower than the other two, so the table reports medians rather than best runs.

### 5. Text selection on very long blocks

**Evidence:** cmux found that `Text(...).textSelection(.enabled)` on macOS lays out the whole text, and drag-selecting a long block can freeze the app ([cmux #4625](https://github.com/manaflow-ai/cmux/issues/4625)). The transcript enables selection on every Markdown block.

Every selectable block is a `SelectionTextField` in a host view. Of the window's 2,082 AppKit views with 240 entries, 840 are these, against 480 for the position markers. In `TranscriptInteractionMeasurements`, after item 8, turning selection off takes the median scroll step from 9.7 to 6.0 ms with 240 entries, and from 34 to 25 ms with 640. It also takes opening Find from 27 to 21 ms.

**Measured (issue #54):** moving `.textSelection(.enabled)` from each Markdown block, code block, and table cell to the message root was tested with `JUSTSESSIONS_PERF=1 swift test -c release --filter TranscriptInteractionMeasurements`. The unchanged baseline was run three times; the prototype once before it was rejected. SwiftUI propagated selection to every `Text` leaf, including labels and list markers, instead of making one surface. The paired `SelectionTextField` and host count rose from 420 to 660 with 240 entries, and from 1,120 to 1,760 with 640. At 640 entries with accessibility off, the median scroll step regressed from 16.5–16.9 ms to 34.4 ms in the single prototype run.

**Conclusion:** keep the current per-block selection. It preserves native selection, links, code-copy controls, table scrolling, and accessibility without the measured regression. One native selection surface for the mixed message hierarchy would require a custom `NSTextView`/TextKit renderer; that wider product and design decision was not taken here.

### 6. Terminal drawing

**Evidence:** this is the largest steady cost: 43% of the main thread's busy time over the whole recording, and up to a fifth of a core while new output took about 1%. When a change reaches the bottom row, SwiftTerm repaints from the changed rows down to the bottom of the view. TUI status lines and spinners do that constantly. The app uses SwiftTerm 1.15.0, through its [fork](build-and-release.md#swiftterm-fork), with CPU drawing.

**Change:** Ghostty, which you can choose under Settings › Appearance › Terminal › Engine, draws with Metal on its own renderer thread, and parses output off the main thread. In the repaint workload, the main thread spent 1.2% of a core on a Ghostty tab, against 14.8% on a SwiftTerm tab; see [Terminal engines](#terminal-engines-ghostty-and-swiftterm).

**SwiftTerm's Metal drawing, measured (issue #52):** the pinned SwiftTerm already has a Metal renderer, off by default, behind `setUseMetal(_:)`; no upgrade is needed to try it. It keeps each row in GPU buffers and redraws only the rows that changed, and falls back to Core Graphics if Metal can't start. The app doesn't turn it on; `TerminalEngineMeasurements` does, for its *SwiftTerm (Metal)* case, so Ghostty, SwiftTerm, and SwiftTerm with Metal run through the same output. Release build, three runs each, medians:

| Workload | SwiftTerm | SwiftTerm, Metal | Ghostty |
| --- | --- | --- | --- |
| Repaint, 1 tab: CPU | 8.8% | 8.8% | 3.4% |
| Repaint, 1 tab: main thread | 6.4% | 7.0% | 0.8% |
| Repaint, 1 tab: longest main-thread gap | 28 ms (25–35) | 182 ms (157–218) | 24 ms |
| Repaint, 1 tab: frames drawn of 150 | 150 | 136 (134–140) | 150 |
| Bulk 20 MB: time | 0.78 s | 0.79 s | 0.20 s |
| Repaint, 5 tabs, 1 shown: CPU | 10.8% | 14.3% | 4.8% |
| Repaint, 10 tabs, 1 shown: CPU | 11.9% | 19.2% | 5.6% |
| Repaint, 10 tabs, 1 shown: frames drawn | 149 | 481 | 150 |

At this SwiftTerm revision, Metal saves no CPU on these workloads, drops about a tenth of the frames, and stalls the main thread for 150–200 ms at a time where Core Graphics stays under 35 ms. With hidden tabs it costs more, not less: a hidden tab's Metal view keeps drawing, since `setNeedsDisplay` on an `MTKView` isn't stopped by a hidden ancestor the way `draw(_:)` is, so the app's hidden-tab batching (`TerminalOutputCoalescer`) would be partly undone. **Not turned on**, and no switch for it is shipped. The measurement case stays so the comparison can be run again after a SwiftTerm upgrade. Not checked: how Metal looks, selection highlights, the cursor, IME, transparency, and Retina scaling, which need a person at a real terminal.

**Plan for SwiftTerm, the default engine:**
1. Upgrade to SwiftTerm 1.20.0 by rebasing the fork onto it. Version 1.16.0 notes improved baseline performance, and 1.20.0 is the last release before breaking changes.
2. Run `TerminalEngineMeasurements` again. Metal is worth turning on only if the gaps, the dropped frames, and the hidden-tab drawing are gone and the CPU saving is real.
3. Then check visually: selection, insets, transparency, the cursor, and the app's own drawing.

The draft line-layout cache ([SwiftTerm #449](https://github.com/migueldeicaza/SwiftTerm/pull/449)) is not merged.

### 7. The search context changes on every transcript update

**Evidence:** `TranscriptScrollView` set `transcriptSearchContext` with a new `reveal` closure on every body evaluation. SwiftUI can't compare closures, so each transcript update re-ran every text block and tool-call list, and remeasured them. With the closure removed, the median scroll step halved: from 71 to 37 ms with 240 entries.

**Change:** the context holds the position controller instead of a closure, and is `Equatable`. It compares the query, the selected match, the navigation revision, and the controller by identity, which is everything text blocks read. See item 8 for the measurements together.

### 8. Scrolling re-rendered every transcript entry

**Evidence:** scrolling changes `visibleEntryIndex`, the `@State` behind the transcript's `.scrollPosition(id:)`, each time a new entry reaches the top. Each change re-ran `TranscriptScrollView.body`, which rebuilt every entry, and SwiftUI then remeasured the whole non-lazy stack. In `TranscriptInteractionMeasurements`, one scroll step took a median of 71 ms with 240 entries, and 187 ms with 640. The window can't draw during those steps, so scrolling a long transcript ran at about 14 frames a second or fewer.

**Change:** the entries are their own view, `TranscriptEntriesStack`, compared by its inputs: the transcript, the provider, and the position controller. These stay the same while you scroll, so SwiftUI skips the entries. Together with item 7:

| Measure | 240 entries, before → after | 640 entries, before → after |
| --- | --- | --- |
| Median scroll step | 71 → 9.7 ms | 187 → 34 ms |
| Worst scroll step, accessibility on | 172 → 15 ms | 459 → 62 ms |
| Opening Find | 82 → 27 ms | 222 → 70 ms |

### 9. SwiftUI's scroll position tracking

**Evidence:** after item 8, much of each scroll step is SwiftUI's own tracking for `.scrollPosition(id:)` and `.scrollTargetLayout()`. On every scroll it searches the entries for the one closest to the anchor (`ScrollStateRequestTransform.findClosestSubview`), then marks the state that changed as dirty. Both grow with the number of entries.

**Change:** the reader no longer uses `.scrollPosition(id:)`, `.scrollTargetLayout()`, or `visibleEntryIndex`. `TranscriptScrollPositionController` already recorded and restored the reading position on its own. Every entry is laid out, so it finds any loaded entry's marker without SwiftUI's help. Where the reader set `visibleEntryIndex`, it also either called `ScrollViewProxy.scrollTo` or asked the controller to restore a position:
- the initial position;
- Find's navigation;
- a page loading or going to the first message with paging;
- **First message** and **Latest message** without paging.

Scrolling no longer updates `TranscriptScrollView` at all. `TranscriptInteractionMeasurements`, release build, median of three runs each:

| Measure | 240 entries, before → after | 640 entries, before → after |
| --- | --- | --- |
| Median scroll step, accessibility off | 10.3 → 4.8 ms | 35.5 → 16.3 ms |
| Median scroll step, accessibility on | 10.8 → 4.9 ms | 37.8 → 17.6 ms |
| 60 scroll steps, accessibility off | 694 → 310 ms | 2,158 → 1,000 ms |
| Worst scroll step, accessibility off | 59 → 22 ms | 56 → 37 ms |

Hit testing and the view count are unchanged. With 240 entries and accessibility off, the first time Find opens after scrolling took 49 instead of 29 ms. Opening it again took 20 instead of 28 to 30 ms. With 640 entries, and with accessibility on, opening Find took about as long as before. The first update after scrolling seems to pay once for what each scroll step paid before.

### 10. Message search decoded every image

**Evidence:** `SessionMessageTextReader` reads a session through the reader's own page source, then drops image entries. By then each image's base64 had been decoded into `Data`, and its header read with ImageIO. A page held all of them until it was done.

**Change:** the reader takes `decodesImages`, and message search turns it off. Each image keeps its entry, holding `TranscriptImage.undecoded`, so the entries after it keep their IDs and turns. The readers hand images to `TranscriptBuilder` through an `@autoclosure`, which it only runs while decoding images.

`MessageSearchReadingMeasurements` reads 100 generated messages, each with one PNG, the way search does:

| Images in each message | CPU, decoding → undecoded | Decoded image bytes a page holds |
| --- | --- | --- |
| None | 3.2 → 3.1 ms | 0 |
| 160 KiB of base64 | 40 → 31 ms | 12 MiB → 0 |
| 744 KiB of base64 | 156 → 135 ms | 49 MiB → 0 |

The gain is smaller on real sessions. On one contributor's 46 Claude Code and 163 Codex sessions with images, 3.3 GB in all, CPU went from 2.46 to 2.37 s and from 7.29 to 7.15 s. The largest page held 10 and 11 MiB of decoded images, and now holds none; the indexer reads 3 sessions at once. JSON parsing, which still reads each base64 string, takes about half of the remaining time for Claude Code, and a third for Codex. In Codex rollouts, most image bytes are in tool outputs and events, which the reader already skips without parsing; only 9% are in messages.

### 11. Codex's compacted records are parsed in full

**Evidence:** a Codex `compacted` record carries the conversation it replaced, images included. The reader only shows a note for it, but `CodexTranscriptReader.mightContainTranscriptItem` lets the line through, so the whole record is JSON-parsed. In the 163 Codex sessions of item 10, these records held 306 MiB of image base64, 16% of all of it, and more than the messages themselves.

**Plan:** measure how much reading time these records take. If it matters, add the note from the line's start, which holds the timestamp and type, without parsing the rest.
### 12. Every reader decoded its own images

**Evidence:** each `TranscriptImageView` decoded its image in a detached task of its own and kept the result. The reader lays out every loaded entry, so opening a session decodes all the images in its loaded pages at once. Opening the session again, after reading another one, decoded them all again. A second reader of the same session, such as a reading window beside the preview, decoded them a second time and kept a second copy.

**Change:** `TranscriptImageDecoder` decodes each image once for every view that shows it. It knows an image by a SHA-256 digest of its bytes, since each reader reads its own `Data` from the session file. Views asking for an image that is decoding wait for that decode. Decoded images stay in an `NSCache` of at most 128 MiB of pixels, which also empties when memory runs low. A view that goes away stops waiting, and a decode nobody waits for any more doesn't start. The digest names the bytes, so a cached image can't be an older version of the one asked for.

It adds no limit on how many images decode at once. Decoding runs off the main thread, and it lengthened the longest main-thread gap by only about 15 ms over the same transcript without images: 224 to 237 ms, against 208 to 219 ms. A limit would only make the images in sight wait for the others.

`TranscriptImageDecodingMeasurements`, release build, two runs each. The session has 24 screenshots of 2880×1800 in 240 entries:

| Measure | Before | After |
| --- | --- | --- |
| One reader: CPU until the process settles | 1.05–1.14 s | 1.04–1.08 s |
| One reader: memory footprint growth | 413 MB | 401–414 MB |
| Opened again after closing: CPU | 1.01–1.16 s | 0.36 s |
| Opened again after closing: memory footprint growth | 378–390 MB | 66–96 MB |
| Two readers at once: CPU | 2.0–2.2 s | 1.25–1.27 s |
| Two readers at once: memory footprint growth | 580–655 MB | 422–429 MB |
| Four readers at once: CPU | 4.3–4.5 s | 2.0 s |
| Four readers at once: memory footprint growth | 1.27 GB | 515–564 MB |

Laying out the same 240 entries without images takes about 0.23 s of CPU, which each extra reader still pays. Time until settled and the longest main-thread gap barely changed, since layout dominates both. The process kept 220 to 530 MB after its readers closed before the change, and 280 to 434 MB after it. Freed memory isn't returned right away, so that measure can't show the cache's share; the cache holds at most 128 MiB.
### 13. Each OpenCode page read every message's data

**Evidence:** to read one page of an OpenCode session, `OpenCodeTranscriptIndex` read every message of the session. SQLite checked and rewrote each message's JSON, and the app then parsed it, before the page read the parts of its own few messages. A user's message keeps the diffs of the files it changed, whole files, in that JSON. Each page of a long session cost as much as reading all of its messages, and paging back through it read them all again for every page.

**Change:** the index reads only the messages' ids, in order, from OpenCode's `(session_id, time_created, id)` index, without reading their data. A page then reads the data of only its own messages, one by one, by id. Nothing is cached between reads, so a message OpenCode rewrites, as when a reply fails, shows on the next read. Each message is a record, including one whose data is unreadable or isn't a user's or an assistant's message; such a record has no entries. OpenCode writes only those two kinds, so record numbers, and the entry ids made from them, stay the same.

`OpenCodeTranscriptPagingMeasurements`, release build, median of five each, two runs before and two after:

| Measure | 1,000 messages, before → after | 10,000 messages, before → after |
| --- | --- | --- |
| Latest page | 6.4–6.8 → 1.7 ms | 50 → 2.2 ms |
| Latest page, then five earlier ones | 37 → 10 ms | 298–300 → 13 ms |
| A page in the middle | 6.2–6.3 → 1.7 ms | 50 → 2.2 ms |
| Whole session read for message search | 29 → 29 ms | 382–384 → 305–307 ms |

Message search reads a session in pages of up to 5,000 entries, so it read the index only a few times before the change. Most of its time is reading every message's data and parts, which it still needs.

### 14. A CLI activity change updates only the rows in view

**Question (issue #61):** when a CLI's activity changes, `ConversationStore` publishes, and every view that observes the store is invalidated. Does that re-render rows whose session didn't change, and would a narrower publication help?

**Measured:** `SidebarInteractionMeasurements`' store-change scenario, release build, with `Self._printChanges()` added to the sidebar's and detail view's bodies for the run. One activity change at 300 and at 2,000 sessions re-ran these bodies, every project expanded by a search, and every project collapsed:

| View | Expanded | Collapsed |
| --- | --- | --- |
| `ConversationSidebarView` | 1 | 1 |
| `WorkspaceDetailView` | 1 | 1 |
| `SidebarProjectSection` | 24–25 | 50 |
| `SidebarProjectRow` | 24 | 24 |
| `SidebarSessionRow` | 21–24 | 0 |

The same at 300 and at 2,000 sessions: the sidebar's lazy list builds only the rows in its viewport, so the count is set by the window, not the library. The turn took 15–18 ms expanded and 8–10 ms collapsed. In a Time Profiler recording of the turn and the one that follows, the app's own bodies, which filter `terminalSessions` and sum up each project's activity, were the top frame in 13% of samples; about 60% were SwiftUI re-measuring the lazy stack's rows (`_LazyLayout_Subviews.apply`, `sizeThatFits`).

**Conclusion:** the store already suppresses unchanged activity, and SwiftUI already limits the work to the rows in view. Cutting the turn further would mean making each row skip its body and layout when its own values didn't change, which needs the rows to stop observing the store and take their values from the section instead. That is a wider change to the sidebar's rows and their menus for a saving of perhaps 5–10 ms on an event that happens at most once a second per CLI. Not done.

### 15. Terminals in minimized windows drew as if in sight

**Evidence:** a tab's terminal batches its output and stops drawing while the tab is hidden behind another, but nothing told it about its window. A selected tab in a minimized window, or one covered by another window, fed and drew every byte as one in sight does. `TerminalWindowVisibilityMeasurements` replays a full-screen TUI repainting 40 rows at 30 frames a second through one `SelectableTerminalView` for 3 seconds, release build, median of five, as a share of one core:

| Window | Before | After |
| --- | --- | --- |
| In sight | 13–22% | 22% |
| Covered by another window | 15–22% | 22% |
| Minimized | 22% | 3.4% |
| Bound: the tab hidden, window in sight | 3.8–4.0% | 3.8% |

The in-sight figure varies between runs with what else the machine is doing; the bound and the minimized figure after the change are steady.

**Change:** `TerminalInsetView` follows its window's `didMiniaturize` and `didDeminiaturize` notifications and treats a minimized window's terminal as a hidden tab: output is batched at 8 Hz and drawing waits, through the same `setWorkspaceActive` both engines implement. Restoring the window flushes and redraws, as selecting a hidden tab does. The CLI keeps running and its process is read as before, so notifications and attention are unaffected. A tab dragged into another window follows that window.

A covered window is left alone. macOS reports `NSWindow.occlusionState` only to a running app, never to a test process, even one with the regular activation policy, so a check on it couldn't be tested here, and the window server's own occlusion culling already applies to its drawing. The measurement keeps the covered state as a reference.

### 16. Typing beside flooding terminals

**Question (issue #58):** every terminal's output is parsed on the main thread. SwiftTerm's `LocalProcess` yields after about 4 ms of delivery per process, and the app batches a hidden tab's output (`TerminalOutputCoalescer`), but nothing shares a budget across terminals. Does a keystroke in one tab wait behind the others' output, and would a cross-terminal scheduler help?

**Measured:** `TerminalFairnessMeasurements`, release build. A quiet SwiftTerm tab runs `cat`; 60 markers are typed into it, one every 50 ms, and each is timed until its echo is in the terminal's buffer, read from the main queue every 2 ms, so a stall there delays the reading as it delays the display. Other tabs flood from scripts on their own pseudo-terminals, visible beside it as split panes or hidden as the workspace hides them.

| Other tabs | Keystroke to echo, p50 / p95 | Flood lines parsed in about 4 s |
| --- | --- | --- |
| None | 2.3 / 6.7 ms | — |
| 1 visible, as fast as it can (about 50 MB/s) | 4.1 / 10.0 ms | 1.6 M |
| 3 visible, as fast as they can | 17 / 24 ms | 1.4 M |
| 5 hidden, as fast as they can | 34 / 44 ms | 3.1 M |
| 1 visible and 5 hidden, as fast as they can | 31 / 49 ms | 2.3 M |
| 1 visible and 5 hidden at 25,000 lines/s each, about a 2 MB/s build log | **1.9 / 4.3 ms** | 0.56 M |
| 1 visible and 5 hidden at 5,000 lines/s each | 2.1 / 4.9 ms | 0.11 M |

Keystrokes wait only when the other terminals print as fast as a pseudo-terminal carries, about 50 MB/s each and 60 MB/s parsed in all, which no CLI does. Six terminals each printing a fast build log, 12 MB/s in all, leave typing where it is alone. Making the hidden tabs' batches smaller (16 or 4 KiB instead of 64) changed nothing, since at flood rates every read from the pseudo-terminal already exceeds the batch size and is parsed on arrival; the wait is the parsing itself.

**Conclusion:** SwiftTerm's per-process budget and the app's hidden-tab batching are enough at any rate a CLI reaches. A shared budget across terminals would only matter under a synthetic flood, and would have to keep SwiftTerm's own backpressure working. Not done. The suite stays to check this again after a SwiftTerm upgrade or with Ghostty, which parses off the main thread.

### 17. SSH connections during a remote refresh

**Evidence:** a refresh runs its folder lookup and six provider copies sequentially; OpenCode and Antigravity also run snapshot and cleanup commands. Without multiplexing, each is a separate SSH login. Cached mirrors and rsync deltas already reduce the bytes copied. This change could not be timed against a live host: Multipass was unavailable and macOS Remote Login was off (`ssh localhost` was refused), so there is no handshake, snapshot, transfer, or cleanup timing and no latency claim.

**Change:** one remote-session refresh gives its folder lookup, snapshot commands, rsync copies, and cleanup commands the same app-owned OpenSSH control socket. Each refresh has a unique directory owned only by the current user, including concurrent refreshes, and explicitly asks its own master to exit before removing the directory on success, failure, or task cancellation; a 60-second persistence limit is the fallback if the app exits first. A stale socket from an earlier process has a different path. Host aliases and their users, ports, jump hosts, host-key policy, and other SSH settings still resolve normally. A host with `ControlMaster no`, `ControlPath none`, `ControlPersist no`, or a control path of its own receives no app-owned sharing.

The unit coverage checks option construction, config precedence, private and distinct socket directories, idempotent teardown, cancellation, and the same options in remote commands and rsync. A disposable Linux target and a separate macOS account remain required to verify actual reuse and teardown over SSH.
### 18. Workspace windows repeated discovery and message indexing

**Evidence:** every workspace window owned a `ConversationStore`, and every store owned its own message index and ran its own full local refresh. `SharedWorkspaceReadMeasurements` compares those isolated objects with the app-scoped service, using eight generated Codex sessions (209,256 source bytes), simultaneous cold indexing, and three release-build runs per configuration. Counts were identical in all three runs; times below are medians.

| Windows | Source reads, isolated → shared | Bytes read | Index entries / folded copies | CPU time | Wall time |
| --- | --- | --- | --- | --- | --- |
| 1 | 8 → 8 | 209,256 → 209,256 | 8 / 8 → 8 / 8 | 18.4 → 18.3 ms | 13.1 → 13.0 ms |
| 2 | 16 → 8 | 418,512 → 209,256 | 16 / 16 → 8 / 8 | 36.1 → 17.7 ms | 13.6 → 12.3 ms |
| 4 | 32 → 8 | 837,024 → 209,256 | 32 / 32 → 8 / 8 | 82.1 → 16.4 ms | 15.0 → 11.8 ms |

Repeating the identical generation caused zero additional reads in every case. A blocked-reader test starts two users while the one read is still in flight and observes one reader call, rather than merely serial calls. Another service-level case blocks full discovery until all windows have joined it. Its adapter scans were 1/2/4 with isolated stores and 1/1/1 when shared; a fake compatible tmux recorded 3/6/12 subprocess probes before and 3/3/3 after. Each configuration ran three times with the same counts.

**Change:** `WorkspaceReadService` is owned by the app and passed to each workspace. It owns one `SessionMessageIndexer`, one set of adapters and command resolver, and one in-flight full-discovery task. The indexer keeps each active search user's session set and indexes their union, so one window changing hosts, filters, or closing cannot prune or cancel another's text. Generations reject a read that finishes after an append, rename, deletion, or host removal changed the desired set. Text leaves memory only after the final search user and the existing grace delay; restarting within it reuses the in-memory index. A closed window leaves the shared discovery running for other waiters, but the final waiter synchronously marks and evicts it so an immediately opened window starts fresh. Adapter scans check cancellation between reads, tmux probes are bounded, and only the current discovery generation commits the selected tmux server. Selection, sidebar filters, expanded projects, terminal tabs, alerts, and all other presentation state remain in each window's store.

**Limits:** this is a service-level proxy, not four real SwiftUI windows. Its cold caches read zero cache bytes; it does not quantify warm cache decoding. Peak RSS was recorded for the process (about 54–56 MB) but was cumulative across cases, so it cannot isolate per-configuration memory; index-entry and folded-copy counts are the useful memory bound. The fake tmux proves subprocess coalescing but is not a live shell or SSH measurement. Periodic lightweight probes remain per window; this change shares only full refreshes and search indexing.

### 19. The working spinner re-rendered the window 30 times a second

**Evidence:** `WorkingSpinner`, the turning arc beside a session whose CLI is working, animated with a `TimelineView(.animation(minimumInterval: 1 / 30))`. Each tick invalidated the window's whole SwiftUI hosting view: in a Time Profiler trace of v1.2.4 at idle with one CLI working and five tabs open, 2,567 of 10,000 ms were inside `NSHostingView.layout` → `ViewGraphRootValueUpdater.render`, every one a full `ViewGraph.updateOutputs` pass, and `TimelineView<>.UpdateFilter.updateValue` the only per-frame trigger in them. The main thread was busy 35% of the time with nothing happening, and every click, tab switch, and keystroke queued behind those renders. A shared clock publishing one angle would have cost the same: the price is the hosting view's re-render, not the number of timelines.

Traces recorded with `xcrun xctrace record --template 'Time Profiler' --instrument Hangs --attach <pid> --time-limit 10s`, attached to the running app, this session's CLI working the whole time, no interaction. Apple M4 Pro, macOS 26.6.1, Xcode 27.0, release builds.

| Build | Main thread busy | Inside `NSHostingView.layout` | Hangs |
| --- | ---: | ---: | --- |
| v1.2.4, before | 35.0% | 25.7% | none |
| After, run 1 | 3.3% | 0.0% | none |
| After, run 2 | 3.0% | 0.0% | none |
| After, run 3 | 3.7% | 0.0% | none |
| After, run 4 | 3.5% | 0.1% | none |

**Change:** the arc is a `CAShapeLayer` in a small `NSViewRepresentable`, turned by a repeating `CABasicAnimation` on `transform.rotation.z` that the render server runs; SwiftUI draws the view once. The animation runs only while the arc can be seen — the view is in a window that is not minimized, neither it nor an ancestor is hidden, and the SwiftUI view hosting it is not at zero opacity, which is how the app keeps hidden content mounted — and is removed otherwise, so a spinner in a hidden tab, a hidden sidebar panel, or a minimized window costs the render server nothing; one in a window covered by another, or clipped out of a scroll view, still turns. Reduce Motion still shows the arc standing still. The stroke color is resolved from the view's effective appearance, as the SwiftUI arc's `ThemePalette.live` was. `WorkingSpinnerRenderingTests` checks the arc draws in the live color of each appearance, that held still it covers the pixels the SwiftUI arc did, and that no view under `Views/` animates with a per-frame `TimelineView` again; `WorkingSpinnerLifecycleTests` checks it stops and restarts with opacity and hiding, and stops on leaving the window.

**Limits:** the remaining 3–4% is Ghostty frame delivery and periodic syncs, not SwiftUI. The hosting view still re-renders whole on every state change it observes, and a tab switch and a right-click still stall in accessibility walks of it; those are separate items.

### 20. The notification bell's list on each sidebar redraw

**Question (issue #176):** the bell in the sidebar header observes the store, so it works out its list on every store change, and the activity sync now also times each wait. Does that slow the sidebar?

**Measured:** `SidebarInteractionMeasurements`, release build, Apple M4 Max, macOS 27.0.1. The bell's branch and its base, `f156493`, ran the populate, filter, store-change, and preview scenarios alternately, twice each; every figure is a median of three. Another session's builds kept the load average between 4 and 6.

| Turn, 2,000 sessions | Base, two runs | Bell, two runs |
| --- | --- | --- |
| A store change, projects collapsed | 6.8, 7.8 ms | 6.7, 7.1 ms |
| A store change, every project expanded | 28.1, 30.3 ms | 33.0, 30.9 ms |
| Listing the sessions (replace and first render) | 38.0, 39.6 ms | 39.2, 35.5 ms |
| Click to preview | 37.5, 40.5 ms | 40.7, 41.2 ms |

A first pass ran the whole suite on the base, then on the bell, minutes apart: populate and preview at 2,000 sessions took 26 and 22 ms on the base and 46 and 40 ms on the bell. Run alternately, both sides took 42–46 ms and 37–41 ms, so that gap was the machine's load changing between the passes.

The list costs one look at each window's tabs and at this window's CLIs in tmux with no tab, never at the sessions, and the store publishes the wait times only when a wait starts or ends (`WaitingForYouStartTimesSyncTests`).

**Conclusion:** no measurable change.

## How to profile

Attach to a running copy, so you keep your windows and sessions. Record in chunks, so you can analyze finished chunks while still using the app:

```sh
pid=$(pgrep -f 'JustSessions.app/Contents/MacOS/JustSessions' | head -1)
xcrun xctrace record --template 'Time Profiler' --instrument Hangs --attach "$pid" --time-limit 120s --output chunk.trace
xcrun xctrace export --input chunk.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > samples.xml
xcrun xctrace export --input chunk.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="potential-hangs"]' > hangs.xml
```

Or open the trace in Instruments. Keep these points in mind:

- **Leave the SwiftUI instrument out of CPU profiles.** Its tracing shows up in the samples. Record it separately and briefly to find which state changes cause updates.
- **Profile a build made like the release.** The release is built on GitHub's `macos-latest` runner, with the macOS 26.5 SDK for v1.0.8. A build with a newer local SDK can compile some calls differently, as item 3 shows. Check a binary's SDK with `otool -l <binary> | grep -A4 LC_BUILD_VERSION`, and build with the Command Line Tools' SDK by setting `DEVELOPER_DIR=/Library/Developer/CommandLineTools`.
- **Test with an accessibility client running.** Many users run Raycast or a window manager, and SwiftUI's accessibility work only happens while one is connected.
- **Measurement suites:** the suites in `Tests/JustSessionsTests/Performance/` record only with `JUSTSESSIONS_PERF=1`; see their doc comments.
  - `MessageSearchReadingMeasurements`: reading generated sessions with images for message search, decoding the images and leaving them undecoded.
  - `SharedWorkspaceReadMeasurements`: isolated and app-shared message indexing and full discovery with one, two, and four workspace consumers.
  - `SidebarInteractionMeasurements`: sidebar interactions.
  - `TerminalVisibilityMeasurements`: hidden terminals.
  - `TerminalWindowVisibilityMeasurements`: a selected terminal while its window is in sight, covered, or minimized.
  - `TerminalFairnessMeasurements`: keystroke-to-echo time in a quiet terminal while other terminals flood, visible and hidden, at full and at set rates.
  - `TerminalEngineMeasurements`: Ghostty and SwiftTerm tabs under the same output, and their memory; see [Terminal engines](#terminal-engines-ghostty-and-swiftterm) and [Build and release](build-and-release.md#performance-measurements) for the commands.
  - `TranscriptInteractionMeasurements`: scrolling, hit testing, and opening Find in a 240- and 640-entry transcript, with SwiftUI's accessibility off and on. Run it with `JUSTSESSIONS_PERF=1 swift test -c release --filter TranscriptInteractionMeasurements`.
  - `OpenCodeTranscriptPagingMeasurements`: paging through OpenCode sessions of 1,000 and 10,000 messages, and reading them for message search.
  - `TranscriptImageDecodingMeasurements`: opening one, two, or four readers of a session full of screenshots, then opening it again.
