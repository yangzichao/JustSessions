# Sidebar search, filters, pins, and selection

[Back to requirements](../README.md)

## Search

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| SBF-01 | Search matches project names and paths, session titles, session IDs, message text, and bookmarks' labels and tags (SBF-05). | `cb71665`, `ed256ab`, `1bb0b55` | `SidebarProjectFilteringTests`, `SearchableSessionTextTests` |
| SBF-02 | Message text is what the reader shows: your messages, the CLI's replies, and tool call summaries, ignoring case and accents, up to each message's preview limit. A matching session stays under its project with the matching line under its title. | `1bb0b55` | `SessionMessageSnippetTests`, `SessionMessageTextReaderTests` |
| SBF-03 | Clicking a message match opens the reader at that message with Find showing the search, also when the session's file changes while the pages load. | `1bb0b55`, `e379e8b` | `TranscriptMatchRevealTests`, `TranscriptSearchStateRevealTests` |
| SBF-04 | Each session is read once for search, most recent first, with progress at the top of the list. Its text is cached in Caches with file identity as well as size and timestamps. Changed files are read again, and a failed read retries with capped backoff while search remains open; text of sessions no longer listed is removed after 30 days; the text leaves memory a minute after the last search closes. | `1bb0b55` | `SessionMessageIndexerTests`, `SessionMessageTextCacheTests` |
| SBF-05 | While searching, a session with a bookmark whose label or a tag holds the search text, ignoring case and accents, stays listed, with the first such bookmark under its title (`a · Label #tag`, then `+N` for more), above a match in its messages; `#tag` finds bookmarks with a tag starting with `tag`. Clicking the session opens the reader at that bookmark's message, as a bookmark jump puts it (RDR-49), without Find, even while its CLI runs; a session found only in its messages opens at the match (SBF-03). Bookmarks are read only while the search has text, and the filters apply as to any search, so an archived session's bookmarks show only with **Show archived** (SBF-24). | Feature request, 23 October 2026 | `MessageBookmarkDetailsTests`, `TranscriptMatchRevealTests`, manual |

## Filters

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| SBF-20 | The Projects filter menu offers **Last 7 days**, one CLI (listing only CLIs installed or with sessions, and not hidden, SBF-25), **Running**, **Waiting for you**, and **Show archived** (SBF-24). The two status filters are exclusive. Filters never hide open tabs. | `cb9c604`, `12abb26`, `8ddfcf5`, `66e5e05` | `ConversationProviderFilterTests`, `RunningSessionsFilterTests`, `WaitingForYouTests` |
| SBF-21 | **Running** lists sessions whose CLI runs in a tab of any window or in tmux after its tab closed, on this Mac or on an SSH host as of its last refresh. | `66e5e05` | `RunningSessionsFilterTests` |
| SBF-22 | **Waiting for you** lists sessions stopped for your answer or done with a turn you haven't seen, including new sessions' tabs. Empty projects hide while a status filter is on. | `8ddfcf5` | `WaitingForYouTests` |
| SBF-23 | The recent filter moves an aging session out within a minute. | `4878267` | `FilteredSidebarProjectionTests` |
| SBF-24 | Archived sessions (DEL-33) are left out of the Projects list, its search, and the menu's other counts, under **Running** and **Waiting for you** too, even while their CLI runs; their tabs stay. **Show archived · N** is off in each new window; turning it on lists them with the others, each with an archive box after its title, and Clear filters turns it off. | `4e97aec` | `ArchivedSessionsTests`, `SidebarProjectFilteringTests` |
| SBF-25 | Unticking a CLI under **Show sessions from** in Settings → General treats it as not installed, in every window and on every host: its sessions leave the Projects list, its search and counts, and the filter menu, and New session stops offering it (DSC-22). A project whose only sessions are that CLI's leaves too; one with no sessions stays. A window filtered to that CLI goes back to all tools. Its open tabs stay, with their notifications and bell rows; one running in tmux with no tab neither notifies nor shows in the bell. Nothing is deleted, and the CLI's sessions are still scanned, so ticking it again lists them at once; All Bookmarks still lists their bookmarks. | Feature request, 7 November 2026 | `HiddenConversationProvidersTests` |

## Pins and names

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| SBF-40 | Projects and sessions can be pinned. Pins keep the order you put them in: a new pin goes last and activity never moves one. Unpinned items stay sorted by activity. | `d5c9dfc`, `dce90de` | `PinnedOrderTests`, `PinnedItemsTests` |
| SBF-41 | A pinned project drags among its host's pinned projects, a pinned session among its project's. Dragging an unpinned one up among them pins it there. A line shows the drop place, the dragged row fades, and a drop lands beside a pinned neighbor in sight so pins hidden by a filter keep their place. Off the list to either side, the line and the row's ghost hide and a drop lands nowhere; over the terminals, a session drops there instead (SPL-15). | `dce90de`, `dc4e62d` | `SidebarPinDragTests`, `PinnedOrderInSidebarTests` |
| SBF-42 | Under a project, rows go pinned sessions, then new sessions still waiting for their CLI, then the rest by last activity. | `fa39b76` | `ProjectSessionRowTests` |
| SBF-43 | A project can be given a display name, kept per project and shown everywhere the project is named. Saving an empty name or the folder name clears it. | `3aabdb2` | `ProjectDisplayNamesTests` |

## Selection

| ID | Requirement | Origin | Related tests |
| --- | --- | --- | --- |
| SBF-60 | ⌘-click toggles and Shift-click selects a range of sessions, across projects. While nothing is selected, the row a running session's tab highlights counts as selected, so clicking a running session and then ⌘- or Shift-clicking another selects both. Right-clicking a selected row resumes, branches, ends, archives or unarchives, or deletes all of them; a bar at the bottom also offers Delete, and End while any of them runs. Ending skips sessions nothing runs and doesn't ask first, as End session from one row doesn't. | `d5c9dfc`, `6fa8a4f` | `SessionMultiSelectionTests`, `SessionEndingAcrossWindowsTests` |
| SBF-61 | Projects can be multi-selected the same way, then archived (with or without deleting their sessions) from the bottom bar or a selected project's menu. A project's arrow expands or collapses it without changing the selection. | `e53fdf3`, `73cc919` | `ProjectMultiSelectionTests`, `SidebarProjectBatchRemovalTests` |
| SBF-62 | Clicking empty sidebar space, or Escape while the sidebar has focus, cancels a batch selection; a single session's conversation stays open. | `36f23f8` | `SessionMultiSelectionTests` |
| SBF-63 | In **Open tabs**, ⌘-click toggles and Shift-click selects a range of tabs, across groups, skipping collapsed groups' tabs. While nothing is selected, the shown tab's row counts as selected; while rows are selected, only they are highlighted. With two or more selected, a bar at the bottom and a selected row's right-click menu offer **Close N tabs…**, which asks once for them all as **Close all tabs in group…** does (TMX-21). A plain click, selecting a tab elsewhere, switching views, clicking empty space, or Escape cancels the selection; closed tabs and tabs a search hides leave it. | `9939b02` | `OpenTabMultiSelectionTests`, `ClosingSeveralTabsStoreTests` |
