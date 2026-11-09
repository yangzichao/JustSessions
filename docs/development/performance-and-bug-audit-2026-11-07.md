# Performance and bug audit November 2026

[Documentation](../README.md) · [Performance history](performance.md) · [Requirements](../requirements/README.md)

This audit tracks correctness defects and performance work for large session libraries and many open tabs. The original findings below are against upstream commit `cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac`, fetched on 7 November 2026; their source links remain pinned to that commit. Fixes were developed from `cd63e90b` (v1.3.1) and passed the validation recorded below on 8 November. The fix pull request's Local verification section records the final tested commit SHA and logs.

## Implementation status

All 16 defects and the three measured performance targets have fixes and regression coverage. Targeted regressions, release measurements, and final integration checks passed. The original reproductions and source links below describe the pre-fix behavior.

| Finding | Implementation and regression evidence |
| --- | --- |
| AUD-01 | SHA-256 of the exact host identifier separates cache directories; migration accepts only an unambiguous exact legacy name. `RemoteMirrorIdentityTests`. |
| AUD-02 | A registry-owned host reservation serializes discovery, mirror reads/publication, and deletion across windows; the actual worker retains it through cancellation. Claude index writes also serialize. `CrossWindowDeletionTests`, `ClaudeConcurrentIndexTests`, `SharedRemoteCopyTests`. |
| AUD-03 | Retained refresh/support tasks cancel on host lifecycle changes; generation checks reject late copies/status. Disconnect cancels pending deletions between native calls, including work owned by a closed window. `RemoteRefreshLifecycleTests`, `CrossWindowDeletionTests`. |
| AUD-04 | Pi copying and deletion accept root and project layouts with existing file/header/symlink guards. `PiRemoteMirrorTests`, `PiRemoteDeletionTests`; disposable Linux SSH fixture passed. |
| AUD-05 | Outline reuse requires a verified prefix: file content lineage, or visible OpenCode SQL columns in one read snapshot. Antigravity changes rebuild the outline. `ConversationOutlineReaderTests`, `OpenCodeConversationOutlineTests`. |
| AUD-06 | Failed message reads retry at 1, 2, 4, 8, 16, then 30 seconds; stopping the last search cancels retries. `SessionMessageIndexerTests`. |
| AUD-07 | Invalid Siteverify envelopes return unavailable; no feedback is stored. All 14 feedback Worker tests passed. |
| AUD-08 | Timeout and opted-in cancellation kill the verified owned process group and reap the immediate child. Successful detached children are preserved. `BoundedProcessRunnerTests`. |
| AUD-09 | A changed file hashes the entire retained prefix before extending offsets; changed bytes rebuild the index. `TranscriptIncrementalIndexTests`. |
| AUD-10 | Pending moves capture host lifecycle and validate the destination before resuming. `TabMovingAcrossWindowsCancellationTests`. |
| AUD-11 | Retry schedules drop hosts with no remaining affected tabs. `RemoteTabReconnectorTests`. |
| AUD-12 | File search fingerprints include inode/device; cache format v3 invalidates old persisted fingerprints. `SessionMessageTextCacheTests`. |
| AUD-13 | Kiro metadata uses a short prefix only when every required metadata field is present; otherwise it parses the full document. `KiroSessionMetadataTests`. |
| AUD-14 | Codex checks regular files, then opens the head with nonblocking/no-follow flags and checks that handle. `CodexAdapterTests`. |
| AUD-15 | Paging validates the opened file, propagates content lineage, and rebuilds retained pages on a source change. `TranscriptPageSourceTests`, `TranscriptPagingModelTests`. |
| AUD-16 | Failed-CLI cleanup ownership is shared across windows; deferred resumes validate the exact owner/requester tab identities. `FailedCLIRestartOwnershipTests`. |
| PERF-A01 | Appended-name reads and parsing move to a utility-priority actor; stale results are dropped. `AppendedSessionNameFollowingTests`, `TerminalScalingMeasurements`. |
| PERF-A02 | Equal per-window search inputs skip union construction and sorting while retry timers remain independent. `SessionMessageIndexerTests`, `SharedWorkspaceReadMeasurements`. |
| PERF-A03 | Recovery ordering uses a linear projection instead of repeatedly mutating split models. `TerminalTabStripRecoveryProjectionTests`, `TerminalScalingMeasurements`. |

The packaged-app launch check also overrides its SSH host list for that process, preventing verification from refreshing or migrating the developer's real host caches.

The follow-up review specifically covered a shared-copy read spanning deletion and a deletion whose window closes before another window disconnects the host. Both paths now retain host ownership through their actual work; the closed window stays out of normal window/refresh election lists.

### Compatibility and remaining coverage

- Ambiguous or sanitized legacy host caches are left untouched and unassigned, so those hosts need a fresh connection to repopulate history. This intentional one-time exception to offline continuity is documented in SSH-106; it does not delete remote data.
- File validation observes identity, size, and timestamps. An in-place rewrite that preserves all observed metadata is not detected by an unchanged check, and a JSONL file cannot provide SQLite-style transactional isolation from a writer changing it during one read. Atomic replacement and changed-file rewrite regressions are covered.
- Search fingerprint validation applies when a session is reevaluated or its cache is loaded; this change does not add a global watcher for otherwise identical conversation inputs.
- Timeout cleanup owns the helper process group. A child that deliberately creates a different process group/session is outside that ownership boundary. Killing a local SSH process also does not prove that every server-side descendant has stopped.
- Live SSH fixtures used `justsessions-test` on Ubuntu 24.04.5, kernel 6.8.0-124-generic, rsync 3.2.7, Python 3.12.3, OpenSSH 9.6p1, and tmux 3.4. They exercised the production Pi copy filters and deletion script with disposable files, including root/project sessions, companions, bad headers, symlinks, already-missing files, and post-deletion mirror refresh. Claude 2.1.300 and Codex 0.162.1 were installed; Pi, Kiro, OpenCode, and Antigravity were not. This was not an actual Pi CLI lifecycle test. A separate macOS SSH account/host was unavailable and remains untested.
- Sustained manual 50–100-tab interaction, accessibility-assisted tab switching, and the user's reported stall remain unprofiled. Passing synthetic measurements does not establish that all lag is resolved.

### Fix validation

The starting v1.3.1 baseline passed `make test`: 2,884 Swift tests in 610 suites, with the existing Gherkin/XCTest suite; the 13 then-existing feedback tests also passed. The first focused fix run passed the non-remote regressions; four remote fixture assertions needed normalized paths or filtering out preexisting local rows. Their corrected rerun passed all 27 tests in four suites. The first optimized performance run passed 12 tests in seven suites. The later integration run passed 52 of 53 tests; its remaining assertion assumed deletion order without fixing fixture timestamps. After setting explicit dates, all four cross-window deletion tests passed. The final release rerun passed seven tests in three suites, including the optimized OpenCode proof, unchanged search inputs, and ordinary OpenCode paging. The first full `make verify` attempt ran 2,932 Swift tests in 620 suites and stopped on three fixture assertions: both engine variants of an SSH move fixture omitted host membership, and the shared-copy stand-in's ten-second gate expired during parallel-suite contention. The fixture now registers its SSH host and uses an explicit async gate; synchronous remote-folder fixtures use the repository's held-thread trait. Production source did not change after the final benchmarks. The corrected full rerun passed. After adding the smoke-launch host override, a further complete run also passed. The fix pull request's Local verification section distinguishes these earlier failed attempts from final verification.

Final validation, 8 November 2026, on macOS 26.7.2, Xcode 27.2 (27B52), Apple Swift 6.4.2 (`swiftlang-6.4.2.1.9`), Apple M4 Pro / 24 GiB:

| Check | Final result |
| --- | --- |
| `make verify` | Passed, exit 0, including the updated launch-check script |
| Swift Testing | 2,932 tests in 620 suites passed; 126.184 seconds |
| Gherkin/XCTest | 151 tests passed |
| Website Python / JavaScript and Workers | 36 Python and 52 JavaScript tests passed; website build passed |
| Localization | Catalog/resources checks and 14 Python tests passed |
| Release-note style | 37 versions passed |
| Bundled tmux | 3.7c linkage, relocation, licenses, deployment target, and persistence checks passed |
| Packaged app | Release build passed; `dist/JustSessions.app` stayed running for eight seconds with saved tabs and SSH hosts disabled for that launch |
| Release performance runs | 12 tests / 7 suites, then 7 tests / 3 suites passed; commands and measurements in item 36 |
| Linux SSH Pi fixtures | Disposable Python-driven fixtures through `justsessions-test` passed; expected refusals/missing-file statuses asserted; production-script hashes matched the verified implementation |
| Whitespace and documentation | `git diff --check` passed; relative documentation links exist and requirement IDs are unique |

These results cover the fixes, tests, and launch-check script developed from `cd63e90b5cffc841a6c3660d160b24270ca1ac5d`; they do not describe that base commit alone. Source manifests recorded the performance and integration-check snapshots. See the fix pull request's Local verification section for the final tested commit SHA, exact commands, and verification, performance, and SSH logs. Run `make verify` from the repository root to repeat the integration checks; the performance commands are in item 36, and the SSH setup and manual checklist are in [SSH development testing](ssh-testing.md).

Measurements, methods, and correctness costs are recorded in [performance item 36](performance.md#36-november-audit-fixes-for-many-tabs-and-sessions).

## Correctness findings (original evidence)

Priority P1 means a high-impact isolation or integrity issue; P2 means incorrect supported behavior; P3 means a lower-impact robustness defect. Reproductions using simplified dependencies are identified explicitly. IDs remain stable as findings are investigated or fixed.

### AUD-01 Different SSH hosts share a mirror directory

**P1 · Fixed; see validation above · Reproduced with production naming helpers.**

`RemoteHostList.normalizedHost` accepts both `dev+gpu` and `dev_gpu`, but `RemoteSessionMirror.directoryName` maps both to `dev_gpu`. The list accepts both names. The same-machine check does not prevent this when they resolve to different machines.

Every provider mirror and `tool-folders.json` uses the colliding directory. Refreshes can overwrite or mislabel another host's cached sessions, and removing either host removes the shared mirror. Permanent remote data loss was not reproduced.

Reproduce by adding both identifiers to a `RemoteHostList` and comparing their mirror-directory components. Both additions succeed and both components are identical.

Use a collision-resistant encoding of the complete host identifier and account for existing cache directories. Test punctuation, Unicode, case, and migration independently of network access.

Sources: [host validation](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Models/Hosts/RemoteHostList.swift#L23), [directory mapping](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Remote/Mirror/RemoteSessionMirror.swift#L269), [mirror removal](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Remote/Mirror/RemoteSessionMirror.swift#L67).

### AUD-02 Concurrent Claude deletions lose index updates

**P2 · Fixed; see validation above · Reproduced with the production index writer.**

`ClaudeConversationIndex.remove` performs an unsynchronized read, modification, and atomic replacement. Atomic replacement prevents partial files but does not prevent two writers from overwriting each other's changes. Deletion and refresh exclusion is per `ConversationStore`, so another window can start overlapping work on the same host and files, contrary to DEL-08.

Two concurrent calls removing different IDs from a generated 10,000-entry index lost one removal in all 20 test rounds. Each call succeeded; the result had 9,999 entries instead of 9,998. The harness released both callers at entry without modifying the production implementation. This proves stale index entries, not restoration of deleted transcript files.

Coordinate deletion and refresh across the app's windows, and serialize index mutations per project. Add a two-window integration test as well as the concurrent writer regression.

Sources: [index writer](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Deletion/Claude/ClaudeConversationIndex.swift#L5), [per-window exclusion](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Store/ConversationStore.swift#L521).

### AUD-03 Disconnect leaves an existing refresh running

**P2 · Fixed; see validation above · Established by control-flow inspection; live SSH reproduction pending.**

`refreshRemoteHost` checks disconnection only before starting its detached task. Disconnect sets the flag and clears running marks, but retains no refresh task to cancel. The discovery loop supports cancellation, but disconnect does not trigger it. Subsequent copies, the final SSH status probe, and completion callbacks can still run. Status setters and shared-copy receivers check host membership, which includes disconnected hosts, and can restore running indicators.

The disconnected choice remains set. The defect is continued automatic work and stale status publication, contrary to SSH-101. Closing the login master is insufficient because refreshes have their own connection-sharing scope.

Retain and cancel refresh tasks and reject completions from an obsolete host generation. Test disconnect, removal, and reconnection while a provider copy or status probe is suspended.

Sources: [refresh task](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Remote/ConversationStore+RemoteHosts.swift#L14), [disconnect](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Remote/Disconnect/ConversationStore+RemoteHostDisconnect.swift#L78), [status setter](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Tmux/ConversationStore+Tmux.swift#L20).

### AUD-04 SSH discovery omits Pi sessions in the sessions root

**P2 · Fixed; see validation above · Reproduced with the exact rsync filters and disposable files.**

Local Pi discovery supports JSONL files directly inside a custom sessions directory. Remote copying includes only project directories and JSONL files one level below the root. A root file is silently excluded while a nested fixture copies successfully; rsync exits successfully. Remote Pi deletion also assumes a project subdirectory.

Support the configured root layout in both copying and deletion, preserving the intentional exclusion of extension folders and credentials. Relevant requirements are DSC-02, SSH-62, and SSH-63.

Sources: [copy filters](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Remote/Mirror/RemoteSessionMirror.swift#L236), [local layout support](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Adapters/Pi/PiSessionsDirectory.swift#L38), [deletion restriction](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Remote/Deletion/Pi/RemotePiConversationDeletion.swift#L17).

### AUD-05 A rewritten earlier message leaves the conversation map stale

**P2 · Fixed; see validation above · Reproduced with production outline logic and a simplified file page source.**

`ConversationOutlineReader.update` attempts incremental extension after any file change. It validates the final anchor but keeps every preceding outline block. Rewriting an earlier message while retaining the last message therefore preserves the old prefix and records the new file stamp. Rebuilding the transcript index repairs offsets without invalidating that retained outline.

Reproduction: read three messages; rewrite only the first; update the same reader; compare with a fresh reader. The change stamp changes, the incremental update returns nil, and the retained first message differs from the fresh result. Production reader, builder, outline, stamp, and page types were used; decoder plumbing was replaced with a simple fresh-file page source.

Validate the retained prefix or rebuild after a rewrite. Add an actual transcript-fixture regression changing only an earlier record. PERF-89 requires rewritten files to be read in full.

Source: [incremental update and prefix retention](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Terminal/ConversationMap/ConversationOutlineReader.swift#L43).

### AUD-06 Message search fails to retry a transient read failure

**P2 · Fixed; see validation above · Reproduced with the production indexer and injected reader/index dependencies.**

A reader returning nil leaves the session absent from the index. The update nevertheless finishes, and subsequent updates return on equal `desiredConversations` before checking missing index entries. Query edits and unchanged refreshes do not retry. Recovery occurs when the desired session set changes or all search users stop and restart.

With a reader failing once, the first update produced `reads=1, indexed=0`; an identical update still produced `reads=1, indexed=0`; restarting search produced `reads=2, indexed=1`. The source comment promises that a later update retries unreadable sessions.

Track failed reads and provide a bounded retry path. Avoid turning progress notifications into a tight retry loop. Coordinate this fix with PERF-A02 so the faster unchanged-input path still retries failures.

Source: [desired-set equality guard](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/MessageSearch/SessionMessageIndexer.swift#L100).

### AUD-07 A null Turnstile response throws unexpectedly

**P3 · Fixed; see validation above · Reproduced by importing the production JavaScript helper.**

If Siteverify returns HTTP 200 with JSON `null`, `verifyTurnstileToken` reads `outcome["error-codes"]` outside its try/catch and throws a TypeError. Injecting a fetch response of `new Response("null", {status: 200})` reproduces it. Validate the response envelope before property access and return the existing unavailable outcome for malformed upstream responses.

Source: [response handling](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Cloudflare/Feedback/src/turnstile-verification.js#L34).

### AUD-08 A timed-out helper leaves its descendants running

**P2 · Fixed; see validation above · Reproduced with the production bounded process runner.**

`BoundedProcessRunner` sends SIGKILL only to its immediate child at the deadline, then returns a timed-out result. A wrapper's children can keep running. This matters for native deletion helpers: a descendant could still finish a deletion after the app reports failure or the user retries. Continued deletion was not performed against real sessions.

An unchanged runner launched a disposable shell that started a delayed marker-writing child and waited. With a 100 ms deadline, the runner returned after about 124 ms with no exit status and no marker. After 800 ms the marker existed, proving that the child continued after timeout. All fixture processes subsequently exited.

Give bounded helpers explicit process ownership and terminate their owned descendants on timeout. Preserve successful helper commands that intentionally leave descendants running, as well as terminal/tmux persistence. Cover wrappers and nested descendants with a regression that asserts no delayed side effect occurs after timeout. Relevant deletion contracts are DEL-02 and DEL-10.

Source: [timeout handling](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Processes/BoundedProcessRunner.swift#L77).

### AUD-09 A middle rewrite followed by an append corrupts cached record offsets

**P2 · Fixed; see validation above · Reproduced with the production transcript index.**

The append fast path validates the file identity, size growth, and only the first and last 256 bytes of the previously indexed content. An in-place change between those edges can preserve both samples while moving record boundaries. The index then scans only the appended bytes and keeps obsolete offsets into the changed middle.

The fixture contained 100 valid JSONL records. Two adjacent middle records were rewritten: one grew by two bytes and the other shrank by two. The old prefix length and both sampled edges stayed unchanged; another 32 bytes were appended to the same inode. Incremental indexing scanned only those 32 bytes and returned invalid JSON slices for both changed records. A fresh index read both correctly. Ordinary append-only logs do not trigger this defect.

Handle rewrites as distinct from verified append-only growth. Any proposed bounded validation needs an explicit correctness contract; checking two edges alone cannot prove the interior is unchanged. Retain a regression large enough that the edits lie outside both edge samples. The stale offsets persist across subsequent unchanged checks and appends; replacing the inode avoids this specific defect. Relevant contracts are PERF-69 and RDR-01. This finding was independently reviewed.

Source: [append classification](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Transcript/Paging/TranscriptFileIndex.swift#L23).

### AUD-10 A pending Move Here can undo Disconnect or reopen a removed host

**P2 · Fixed; see validation above · Reproduced in two store-level regression tests.**

Moving an SSH tab waits for a queued remote tmux confirmation. Its completion unconditionally resumes the captured conversation without checking whether the host was disconnected or removed while waiting. The launch path reconnects a disconnected host automatically.

The tests suspended the remote runner, disconnected or removed the host, then released a successful confirmation. After Disconnect, the disconnected flag became false and a tab opened in the destination window. After removal, neither the host nor the conversation remained listed, yet a tab opened for that removed host. Both tests used actual stores and the two-window test sandbox, with an injected runner and discovery; they started no SSH connection or real CLI. Two runs each failed the same three expected-behavior assertions.

Invalidate pending moves when host lifecycle changes and revalidate the destination before launching. Preserve the intentional behavior that closing the source tab alone while confirmation is pending may still resume it in the destination. Disconnect's later intent must win; see SSH-101 and RDR-06.

Sources: [asynchronous move completion](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Windows/MovingTabs/ConversationStore+MovingTabsHere.swift#L27), [unconditional launch](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Windows/MovingTabs/ConversationStore+MovingTabsHere.swift#L45), [automatic connection](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Launch/ConversationStore+Launch.swift#L62).

### AUD-11 Reconnect keeps probing after its last affected tab closes

**P2 · Fixed; see validation above · Reproduced with the production reconnector and schedule, using stub registry/store/tab types and a fake probe.**

A dropped tab schedules host retries. Closing the final affected tab does not remove that schedule. `askDueHosts` checks host membership and disconnection, but never checks whether any open tab still needs reconnection. A failed probe schedules another attempt, potentially continuing for the 15-minute retry window even with no affected tabs open.

The harness dropped an SSH tab and simulated closing it by removing it from the stub store before the first two-second deadline, keeping a workspace registered. With zero open tabs, the first deadline still invoked the probe; advancing to the next retry invoked it again. Inspection separately confirmed that the real close path does not cancel this schedule. Success, host removal, disconnection, or exhaustion of the retry budget stops the attempts. These are reconnection probes, separate from intentional refreshes and activity monitoring of detached sessions. This finding was independently reviewed.

Prune hosts with no remaining reconnect candidates before starting or rescheduling a probe, and test closing tabs in one and multiple windows. Preserve SSH-89's retries while an affected tab remains open.

Source: [scheduled probe and retry](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Remote/Reconnect/RemoteTabReconnector.swift#L109).

### AUD-12 Search reuses old text after a timestamp-preserving replacement

**P3 · Fixed; see validation above · Reproduced with the production search fingerprint and cache.**

The file-backed search fingerprint includes path, conversation activity time, byte count, and modification time, but excludes file identity. Replacing a transcript with different content of the same size while preserving its modification time and session activity leaves that fingerprint unchanged. The text cache returns the old content as current even though the inode changed.

An atomic replacement fixture produced `file replaced=true`, `search fingerprint equal=true`, and cached `old message` while the file contained `new message`. This is a timestamp-preserving replacement edge case, such as restored/imported data; it is not established as a cause of everyday lag. It does not describe the separate OpenCode database fingerprint path.

Include file identity in the file-backed fingerprint and invalidate older persisted cache entries when its format changes. Test equal-size replacements with preserved timestamps.

Source: [search fingerprint](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/MessageSearch/Cache/SessionMessageTextFingerprint.swift#L6).

### AUD-13 Kiro metadata's prefix shortcut loses fields after session_state

**P3 · Fixed; see validation above · Reproduced with the production Kiro metadata reader.**

The reader commits to the JSON prefix before `session_state` whenever that prefix contains `session_id`. It does not fall back when `cwd` or other metadata appears later. A valid file with `session_id` first and `cwd` after the state is omitted; with ID and cwd first but `parent_session_id` after the state, the parent is lost and a hidden subagent can be listed as a top-level session.

Both cases reproduced with generated 131 KiB JSON files. Parsing the complete object returned the correct metadata while the file initializer returned nil or lost the parent. Current Kiro CLI output normally places these fields first; no current CLI was shown producing this mixed order. This is a reordered/imported-file robustness issue. Existing tests cover all fields before or all fields after state, rather than mixed placement.

Fall back when required metadata is missing, and establish how optional fields are validated before relying on the prefix. Preserve DSC-08's exclusion of Kiro child sessions.

Source: [prefix acceptance](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Adapters/Kiro/KiroSessionMetadata.swift#L29).

### AUD-14 A transcript-named pipe can block Codex discovery indefinitely

**P2 · Fixed; see validation above · Reproduced at the production rollout reader; adapter path confirmed by inspection.**

Codex discovery requests `isRegularFile` metadata but does not check it before opening files named `rollout-*.jsonl`. A named pipe matching that pattern reaches a blocking file open/read. Cancellation is checked before that call and cannot interrupt it, so a malformed local session directory can stall discovery.

A disposable FIFO passed to the unchanged rollout reader remained blocked without a writer for the observation interval. Opening a fixture writer released it, and the reader parsed the supplied head. No fixture process remained running. The demonstrated trigger is a deliberately created nonregular file; a live remote mirror was not exercised.

Reject nonregular files before reading and account for file replacement between checking and opening. Pi already explicitly excludes pipes and symbolic links under DSC-06; give Codex equivalent protection without interpreting that Pi-specific requirement as existing Codex coverage.

Sources: [unchecked discovery entry](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Adapters/Codex/CodexAdapter.swift#L36), [blocking head read](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Adapters/Codex/CodexRolloutHead.swift#L20).

### AUD-15 Pagination applies an old index to a replaced transcript

**P2 · Fixed; see validation above · Reproduced with production paging components and a simplified payload decoder.**

After building its index, `TranscriptPageSource` reopens the current file path for each page without validating that handle against the cached index. Ordinary earlier/later/first/latest requests do not request index refresh. If a file is replaced between pages, the old byte ranges are applied to the new file. Invalid JSON slices can be skipped as though those records had no messages.

The fixture read page one, atomically replaced the file with a longer first record, then requested the next page. It returned zero entries, consumed the remaining indexed records, and reported no later page. An explicit index refresh returned the correct entry. Production page source, reader, assembler, index, fingerprint, and limits were used; the JSON payload decoder and unused provider/Markdown paths were simplified.

Validate each opened handle before using cached offsets, and propagate a source-change result so the model can rebuild its pages consistently. The app's refresh on conversation activity changes narrows the race but does not remove it. This GUI interaction was not exercised live. Unlike AUD-09, atomic replacement that shifts existing record boundaries can trigger this defect; no sampled-edge bypass is needed. Relevant contracts are RDR-01, RDR-20, and RDR-21.

Sources: [cached index and reopened file](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Transcript/Paging/TranscriptPageSource.swift#L54), [pagination without refresh](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Views/Preview/Paging/TranscriptPagingModel.swift#L44).

### AUD-16 Repeated Resume can terminate the newly restarted CLI

**P2 · Fixed; see validation above · Reproduced with production stores, a private tmux server, and a stand-in CLI.**

When a failed CLI's dead pane is retained in tmux, Resume queues cleanup before replacing its tab. Two Resume requests made before replacement can queue two kills for the same tmux session name. If the first completion replaces the tab and starts its CLI before the second cleanup runs, that stale cleanup kills the new CLI. The completion checks the old tab's identity only after executing the kill.

The regression held the per-host queue to control that interleaving, used a disposable CLI that failed once and then ran, and resumed twice. Before releasing the second cleanup, the restarted tab had not exited and its pane was live. Afterward, the same current tab had exited and its pane was gone. One test failed two expected-behavior assertions in 0.834 seconds. It used a private tmux 3.7b server, temporary home/project, and actual terminal view; no real provider CLI, user session, app tmux server, or SSH host was touched. This establishes the race, not its frequency in ordinary use.

Deduplicate pending restarts or validate cleanup ownership before killing. A guard on the later completion alone cannot protect the new process. Preserve TMX-24's restart-in-place behavior and cover overlapping Resume with unrelated queued tmux work.

Source: [queued cleanup and late identity check](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Launch/ConversationStore+Launch.swift#L89).

## Measured performance targets

These optimized standalone measurements exercise production source with disposable data. Some dependencies were simplified; these are component costs rather than end-to-end UI latency. They ran on arm64 macOS 26.7.2 with Swift 6.4.2, on a shared machine; the main verification build overlapped some runs.

### PERF-A01 Read appended Pi records off the main actor

The once-per-second name follower opens files and scans appended records directly on the main actor. The reader caps each file's catch-up at 256 KiB, but the cost adds across active tabs. Eleven repetitions used cached temporary files, with writes outside timing and the actual reader plus marker-filter operation.

| Files | Unchanged CPU p50 | About 6 KiB appended per file | More than 256 KiB appended per file |
| --- | ---: | ---: | ---: |
| 20 | 0.18 ms | 0.75 ms | 15.6 ms |
| 50 | 0.32 ms | 1.36 ms | 39.3 ms |
| 100 | 0.67 ms | 2.74 ms | 78.6 ms |

Move reading and parsing off-main, then validate tab/session identity before applying results. Preserve LIV-02's roughly one-second name updates. [Polling source](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/Terminal/AppendedSessionNames/ConversationStore+AppendedSessionNames.swift#L16).

### PERF-A02 Avoid sorting unchanged search inputs

Each query update and index-progress revision rebuilds and sorts the union of listed sessions before checking equality, on the main actor. Progress can publish every 250 ms. An actual-indexer harness with reduced data/index dependencies measured 100 unchanged calls per size:

| Sessions | CPU p50 | CPU p95 |
| --- | ---: | ---: |
| 1,000 | 0.734 ms | 0.821 ms |
| 10,000 | 6.626 ms | 7.405 ms |

Separate query reruns from changes to the indexed corpus, or compare unchanged per-user inputs before rebuilding the union. Preserve the failure-retry path described in AUD-06. [Indexer source](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Services/MessageSearch/SessionMessageIndexer.swift#L94).

### PERF-A03 Cache recovery ordering for cross-project splits

Every changed tab selection persists recovery state. Constructing that state separates all splits in a copied tab strip, repeatedly recalculating group order. Production model code, median of three optimized runs:

| Tabs | Cross-project splits | Separation p50 | Same-project pairs p50 |
| --- | ---: | ---: | ---: |
| 25 | 12 | 0.084 ms | 0.016 ms |
| 50 | 25 | 0.658 ms | 0.051 ms |
| 100 | 50 | 5.095 ms | 0.250 ms |
| 250 | 125 | 75.612 ms | 1.457 ms |

JSON persistence itself was about 0.3 ms at 100 tabs and 0.6 ms at 250. Cache structural ordering or produce the recovery projection directly; retain immediate recovery saves required by TMX-41. These measurements exclude full store snapshot assembly. [Separation loop](https://github.com/yangzichao/JustSessions/blob/cec4eac871c6ef99cb5d5b35d8a4fd6cec95abac/Sources/JustSessions/Models/Terminal/Split/TerminalTabStrip.swift#L125).

## Conditional targets and corrected hypotheses

- A populated Projects search remains active after switching to Open tabs or hiding the sidebar. Its original and folded message text stays in memory. Suspending indexing while retaining the query and scroll state could reduce work; memory impact depends on the library and active searches.
- Actual tab-state publications invalidate many readers of `terminalSessions`, including hidden panel parents. Ordinary selection and unchanged activity/name polls do not bump the global revision. Parent invalidation does not prove every child redraws or that native hidden terminals draw.
- Native terminal views are created eagerly, including restored tabs awaiting first selection. Lazy first creation is a memory/startup candidate; discarding used terminals requires preserving scrollback, selection, Find, and split sizing. No leak was established.
- Repeated whole-library name lookups apply mainly to named Claude tabs. Pi/Codex invoke them only after new name records. The observed running workload was Pi/Codex, so the Claude path does not explain that sample.
- A live-following provider-set rebuild measured about 0.32 ms at 3,000 sessions and 0.78 ms at 10,000. It is avoidable but insufficient by itself to explain substantial lag at those sizes.
- New/Branch tabs refresh their host when leaving the screen even after linking. SPL-10 explicitly requires this behavior; changing its frequency requires a freshness decision, not merely removing the calls.
- Split-pane gesture-state reset currently takes the drop path for release and cancellation. Escape during a highlighted drag needs an event-level reproduction before classifying this as a defect.
- Each workspace owns a separate Sparkle updater, timer, and update cycle. A shared app-owned manager could avoid duplicate resources. Duplicate network checks depend on settings and timing and were not measured; this is not established as a source of the reported lag.

## Original audit verification and coverage

`make verify` passed on the audited commit on 7 November 2026, with macOS 26.7.2, Xcode 27.2, and Swift 6.4.2. The initial attempt stopped because Xcode lacked the Metal Toolchain; after installing component 27B47, the complete command passed.

| Check | Result |
| --- | --- |
| Swift Testing | 2,878 tests in 609 suites passed |
| Gherkin/XCTest | 151 tests passed |
| Website Python tests | 36 passed |
| Website and Worker JavaScript tests | 51 passed across traffic, feedback, browser scripts, and update feed |
| Localization Python tests | 14 passed; extraction/catalog checks passed |
| Release-note style | 36 versions checked |
| Website build | Seven pages, links, assets, metadata, capabilities, and sitemap validated |
| Bundled tmux | 3.7c linkage, relocation, licenses, and process persistence checks passed |
| Packaged app | Release build passed; app stayed running for eight seconds |
| Additional split-model exercise | 98,954 randomized operations over 100 seeds passed identity, grouping, split, and movement invariants |
| Shell syntax | 30 scripts passed |
| Whitespace | `git diff --check` passed |

At this original audit stage, the standard suite did not cover the new regression scenarios above. Actual SSH behavior on disposable Ubuntu and separate macOS targets, sustained 50–100-tab interaction, accessibility-assisted tab switching, and split-drag cancellation were not exercised. The later Linux fixture coverage is recorded under Fix validation. `actionlint` was unavailable. A filename-only scan found no matches for the selected private-key and common credential patterns; this was not an exhaustive secret audit.

The continued investigation added disposable regression tests and standalone harnesses after that baseline verification. `swift test --no-parallel --filter AuditAsyncMoveRaceTests` reproduced AUD-10 twice: two tests failed three assertions per run, demonstrating the existing bugs. `swift test --no-parallel --filter AuditRepeatedResumeRaceTests` reproduced AUD-16 with one test failing two assertions. Those temporary tests were saved separately and removed from the audited checkout afterward. The standalone harnesses demonstrated AUD-08, AUD-09, and AUD-11 through AUD-15; their dependency seams and narrow triggers are described above. No implementation fixes had been applied at that audit stage. The implementation and permanent regression coverage above supersede those open failures.

A ten-second sample of the running v1.3.0 app showed about 489 MiB of physical footprint, with roughly 92% of main-thread samples in the event wait. The earlier v1.2.21 sample reported 1.3 GiB. These snapshots used different app versions and workloads, so they are not a before/after benchmark or proof of a leak. The reported interaction stall has not been captured directly.

## Further investigation

Prioritize a live profile of the reported tab-switching stall and the remaining macOS SSH coverage. Cross-window lifecycle and mutation regressions are now included in the fix suite. Continue examining terminal/process ownership and malformed-input boundaries. Add new confirmed defects with the next AUD ID, keep unverified scenarios explicitly conditional, and record regression evidence before closing a finding.

### Reproducing the regression coverage

The original investigation used disposable fixtures, harness sources, and binaries. Those standalone harnesses are historical evidence rather than repository tools; the finding descriptions above preserve their triggers, outputs, and dependency limitations. Swift harnesses were compiled with `swiftc -O -parse-as-library` and a temporary module cache. Permanent regression suites now cover the fixes:

| Finding | Original reproduction | Permanent regression suite |
| --- | --- | --- |
| AUD-08 | `TimeoutAudit.swift`: timed-out child and surviving grandchild | `BoundedProcessRunnerTests` |
| AUD-09 | Offset-index harness: middle rewrite plus append | `TranscriptIncrementalIndexTests` |
| AUD-10 | `AuditAsyncMoveRaceTests`: delayed Move Here confirmation | `TabMovingAcrossWindowsCancellationTests` |
| AUD-11 | `ReconnectAudit.swift`: failed host after its last tab closes | `RemoteTabReconnectorTests` |
| AUD-12 | Search-cache harness: equal-size replacement with preserved modification time | `SessionMessageTextCacheTests` |
| AUD-13 | `KiroMetadataAudit.swift`: fields following `session_state` | `KiroSessionMetadataTests` |
| AUD-14 | `FifoDiscoveryAudit.swift`: session filename naming a FIFO | `CodexAdapterTests` |
| AUD-15 | Paging harness: atomic replacement between page requests | `TranscriptPageSourceTests`, `TranscriptPagingModelTests` |
| AUD-16 | `AuditRepeatedResumeRaceTests`: overlapping failed-CLI cleanup | `FailedCLIRestartOwnershipTests` |

After the [development build setup](build-and-release.md), run these focused suites from the repository root:

```sh
swift test --no-parallel --filter 'BoundedProcessRunnerTests|TranscriptIncrementalIndexTests|TabMovingAcrossWindowsCancellationTests|RemoteTabReconnectorTests|SessionMessageTextCacheTests|KiroSessionMetadataTests|CodexAdapterTests|TranscriptPageSourceTests|TranscriptPagingModelTests|FailedCLIRestartOwnershipTests'
```

The original audit verification, failed reproduction outputs, and final fix verification are separate evidence sets. See the fix pull request's Local verification section for the recorded commit and logs; the historical temporary test names above are not current test selectors.

### Release-runner follow-up, 9 November 2026

The first `v1.4.0` release run failed before signing or publication ([run 42687072461](https://github.com/yangzichao/JustSessions/actions/runs/42687072461)), despite passing local verification. It reported 62 issues, mostly terminal and UI timeouts, on the smaller macOS runner. Two new tests could occupy shared Swift concurrency threads while their own tasks needed a free thread to release them: the appended-name reader fixture and the opted-in process-cancellation test. Both now use the existing `.oneHeldThreadAtATime` trait; the name suite also serializes its cases. Error cleanup releases or cancels the worker and awaits completion before disposing of its files.

The name fixture's ten-second automatic release could let a name apply before the test reached its close/relink action. It now waits for explicit release. The remote-refresh fixture received the same correction while preparing 1.4.0. These fixes preserve the intended ordering without changing production lifecycle guards or weakening assertions.

CI also exposed a pre-existing scroll-restoration fixture that expired after 60 seconds before its assertion resumed at about 113 seconds. The explicit-handover fixture now keeps restoration pending until the test releases it; separate seek and bookmark tests retain the production settling interval and automatic-completion checks. The widespread timeout pattern is consistent with worker starvation, but the log alone does not prove that every reported failure had that cause. The corrected candidate is 1.3.2; the failed 1.4.0 tag remains unchanged and unpublished. Release verification and CI results are recorded separately in the release pull request.
