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

## Work items

| # | Item | Status |
| --- | --- | --- |
| 1 | [Timestamp parsing](#1-timestamp-parsing) | Done: #46 |
| 2 | [Transcript text searches only during Find](#2-transcript-text-searches-only-during-find) | Done: #46 |
| 3 | [Fast `AttributedString` to `String` conversion](#3-fast-attributedstring-to-string-conversion) | Done: #46 |
| 4 | [One position marker view per transcript entry](#4-one-position-marker-view-per-transcript-entry) | Planned |
| 5 | [Text selection on very long blocks](#5-text-selection-on-very-long-blocks) | Planned |
| 6 | [Terminal drawing: SwiftTerm upgrade, then Metal](#6-terminal-drawing-swiftterm-upgrade-then-metal) | Planned |
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

### 6. Terminal drawing: SwiftTerm upgrade, then Metal

**Evidence:** this is the largest steady cost: 43% of the main thread's busy time over the whole recording, and up to a fifth of a core while new output took about 1%. When a change reaches the bottom row, SwiftTerm repaints from the changed rows down to the bottom of the view. TUI status lines and spinners do that constantly. The app uses SwiftTerm 1.15.0, through its [fork](build-and-release.md#swiftterm-fork), with CPU drawing.

**Plan:**
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
  - `TranscriptInteractionMeasurements`: scrolling, hit testing, and opening Find in a 240- and 640-entry transcript, with SwiftUI's accessibility off and on. Run it with `JUSTSESSIONS_PERF=1 swift test -c release --filter TranscriptInteractionMeasurements`.
