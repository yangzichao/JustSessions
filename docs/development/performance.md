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

| Measure | Ghostty | SwiftTerm, shipped 500 lines | SwiftTerm, 10,000 lines |
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

**Scrollback differs by engine.** A Ghostty tab keeps far more scrollback than a SwiftTerm tab by default: 46,341 rows here, against SwiftTerm's 500 lines. Full, it holds about 55 MB, against well under 1 MB for SwiftTerm's 500 lines, or 30 MB for 10,000. The app sets no limit for Ghostty, so Ghostty's default `scrollback-limit` applies. Upstream documents it as 10,000,000 bytes, so how Ghostty counts it against these 55 MB is unconfirmed.

**Profile:** one 5-second `sample` of the repaint for each engine.
- **SwiftTerm:** the main thread was busy in 721 of 3,675 samples, 20%. Parsing the output (`feed`) took 12 of them, and Core Animation's commit, drawing the view, 693. No other thread did measurable work. The drawing went to:
  - 251 samples in `NSView` drawing, where SwiftTerm's `drawTerminalContents` records each row's text;
  - 417 in updating the layer's backing store, which replays those commands. 316 of them rasterized glyphs into the 16-bit RGBA backing store this XDR display gets (`RGBAf16_mark_constmask`, `vCGCompositeConstMask_ARGB16F_vec`).
- **Ghostty:** the main thread was busy in 28 of 3,459 samples, under 1%: committing the layer's new contents, and handing output on. Ghostty's renderer thread took 29 samples, Metal's command queue 21, Ghostty's output parsing 6, and reading the pseudo-terminal 5. All threads together were busy in 94 samples, against SwiftTerm's 726.

## Work items

| # | Item | Status |
| --- | --- | --- |
| 1 | [Timestamp parsing](#1-timestamp-parsing) | Done: #46 |
| 2 | [Transcript text searches only during Find](#2-transcript-text-searches-only-during-find) | Done: #46 |
| 3 | [Fast `AttributedString` to `String` conversion](#3-fast-attributedstring-to-string-conversion) | Done: #46 |
| 4 | [One position marker view per transcript entry](#4-one-position-marker-view-per-transcript-entry) | Planned |
| 5 | [Text selection on very long blocks](#5-text-selection-on-very-long-blocks) | Planned |
| 6 | [Terminal drawing](#6-terminal-drawing) | Done for Ghostty, the engine you can choose in Settings: libghostty PR. Planned for SwiftTerm, the default |
| 7 | [The search context changes on every transcript update](#7-the-search-context-changes-on-every-transcript-update) | Done: scrolling PR |
| 8 | [Scrolling re-rendered every transcript entry](#8-scrolling-re-rendered-every-transcript-entry) | Done: scrolling PR |
| 9 | [SwiftUI's scroll position tracking](#9-swiftuis-scroll-position-tracking) | Done: issue #55 |
| 10 | [Message search decoded every image](#10-message-search-decoded-every-image) | Done: issue #59 |
| 11 | [Codex's compacted records are parsed in full](#11-codexs-compacted-records-are-parsed-in-full) | To investigate |

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

**Plan:** track the reading position from the scroll view's geometry instead, so loaded entries add no AppKit views. The position controller uses each marker for more than recording the position:
- restoring a position within an entry;
- finding where a page's first entry starts;
- revealing search matches.

It also restores the position from the marker's `layout()`, in the same layout pass as a page loading above, so the reader never sees the content jump. A replacement must keep that timing. The reading-position and paging tests cover these cases.

### 5. Text selection on very long blocks

**Evidence:** cmux found that `Text(...).textSelection(.enabled)` on macOS lays out the whole text, and drag-selecting a long block can freeze the app ([cmux #4625](https://github.com/manaflow-ai/cmux/issues/4625)). The transcript enables selection on every Markdown block.

Every selectable block is a `SelectionTextField` in a host view. Of the window's 2,082 AppKit views with 240 entries, 840 are these, against 480 for the position markers. In `TranscriptInteractionMeasurements`, after item 8, turning selection off takes the median scroll step from 9.7 to 6.0 ms with 240 entries, and from 34 to 25 ms with 640. It also takes opening Find from 27 to 21 ms.

**Plan:** keep live selection under a size limit, and offer **Copy Text** for longer blocks. Measure first whether one selectable view per entry, instead of one per block, keeps selection usable with fewer views.

### 6. Terminal drawing

**Evidence:** this is the largest steady cost: 43% of the main thread's busy time over the whole recording, and up to a fifth of a core while new output took about 1%. When a change reaches the bottom row, SwiftTerm repaints from the changed rows down to the bottom of the view. TUI status lines and spinners do that constantly. The app uses SwiftTerm 1.15.0, through its [fork](build-and-release.md#swiftterm-fork), with CPU drawing.

**Change:** Ghostty, which you can choose under Settings › Appearance › Terminal › Engine, draws with Metal on its own renderer thread, and parses output off the main thread. In the repaint workload, the main thread spent 1.2% of a core on a Ghostty tab, against 14.8% on a SwiftTerm tab; see [Terminal engines](#terminal-engines-ghostty-and-swiftterm).

**Plan for SwiftTerm, the default engine:** a tab that uses SwiftTerm still draws on the CPU, on the main thread.
1. Upgrade to SwiftTerm 1.20.0 by rebasing the fork onto it. Version 1.16.0 notes improved baseline performance, and 1.20.0 is the last release before breaking changes.
2. Then try `setUseMetal(true)`. The Metal renderer caches each row and rebuilds only changed rows.
3. Check visually: selection, insets, transparency, the cursor, and the app's own drawing.

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
  - `SidebarInteractionMeasurements`: sidebar interactions.
  - `TerminalVisibilityMeasurements`: hidden terminals.
  - `TerminalEngineMeasurements`: Ghostty and SwiftTerm tabs under the same output, and their memory; see [Terminal engines](#terminal-engines-ghostty-and-swiftterm) and [Build and release](build-and-release.md#performance-measurements) for the commands.
  - `TranscriptInteractionMeasurements`: scrolling, hit testing, and opening Find in a 240- and 640-entry transcript, with SwiftUI's accessibility off and on. Run it with `JUSTSESSIONS_PERF=1 swift test -c release --filter TranscriptInteractionMeasurements`.
