import AppKit
import Combine
import Foundation
import SwiftUI
import Testing
@testable import JustSessions

/// Measures what a user feels in the sidebar, one interaction at a time, with the real sidebar and detail views
/// hosted in a visible 1400×900 window. Each scenario runs 3 times in-process and the median run (by total time)
/// is reported, as `Perf | <scenario> | <metric> | <value>` lines. With `JUSTSESSIONS_PERF_LOG_DIR` set, the
/// lines are also appended to `interactions.log` in that directory.
///
/// The suite records nothing unless `JUSTSESSIONS_PERF` is set, so a plain `swift test` stays fast:
///     JUSTSESSIONS_PERF=1 swift test --filter SidebarInteractionMeasurements
///
/// Soak mode repeats one scenario at N=2,000 for about 15 s so `/usr/bin/sample` can catch its hot stacks:
///     JUSTSESSIONS_PERF=1 JUSTSESSIONS_PERF_SOAK=<scenario> swift test --filter SidebarInteractionMeasurements/soak
/// The soaking process prints its pid and, with `JUSTSESSIONS_PERF_LOG_DIR` set, writes it to `soak.pid` there
/// before looping, so a script can attach the sampler.
@MainActor
@Suite(.serialized)
struct SidebarInteractionMeasurements {
    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil
    }

    /// The launch scan's apply: `replaceConversations(on: .thisMac, with: all)` into the shown, empty window.
    @Test(arguments: [300, 2_000])
    func populate(sessionCount: Int) async throws {
        try await measureScenario(.populate, sessionCount: sessionCount)
    }

    /// "session 1" typed one character at a time through the real search-text binding, then cleared.
    @Test(arguments: [300, 2_000])
    func typingInSearch(sessionCount: Int) async throws {
        try await measureScenario(.typing, sessionCount: sessionCount)
    }

    /// Recency All -> Recent -> All, then a provider filter on -> off, through the real bindings.
    @Test(arguments: [300, 2_000])
    func filterToggles(sessionCount: Int) async throws {
        try await measureScenario(.filters, sessionCount: sessionCount)
    }

    /// Click the first visible session, Shift-click the last visible one (the real SessionMultiSelection range
    /// logic over the sidebar's visible order), then clear.
    @Test(arguments: [300, 2_000])
    func selection(sessionCount: Int) async throws {
        try await measureScenario(.selection, sessionCount: sessionCount)
    }

    /// With every project expanded, the sidebar's scroll view scrolled top to bottom in 20 steps.
    @Test(arguments: [300, 2_000])
    func scrolling(sessionCount: Int) async throws {
        try await measureScenario(.scroll, sessionCount: sessionCount)
    }

    /// One 1 Hz poll tick that changed something: `store.detachedCLIActivities[<one listed id>] = .working`.
    @Test(arguments: [300, 2_000])
    func oneSmallStoreChange(sessionCount: Int) async throws {
        try await measureScenario(.storeChange, sessionCount: sessionCount)
    }

    /// Selecting one session row the way the sidebar's click handler does, with a small real transcript file.
    /// Only the synchronous turn is measured; the transcript itself loads asynchronously afterwards.
    @Test(arguments: [300, 2_000])
    func openPreview(sessionCount: Int) async throws {
        try await measureScenario(.preview, sessionCount: sessionCount)
    }

    /// Repeats `JUSTSESSIONS_PERF_SOAK`'s scenario at N=2,000 for about 15 s so sample(1) can watch it.
    @Test func soak() async throws {
        guard Self.isEnabled,
              let scenarioName = ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF_SOAK"],
              let scenario = SidebarPerfScenario(rawValue: scenarioName) else { return }
        let harness = try await SidebarPerfHarness(sessionCount: 2_000)
        defer { harness.close() }
        let pid = ProcessInfo.processInfo.processIdentifier
        if let logDirectory = perfLogDirectory() {
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            try "\(pid)\n".write(to: logDirectory.appendingPathComponent("soak.pid"), atomically: true, encoding: .utf8)
        }
        perfReport("soak-\(scenario.rawValue)", "pid", pid)
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(15)
        var iterations = 0
        while clock.now < deadline {
            try await harness.prepare(for: scenario)
            _ = try await harness.run(scenario)
            iterations += 1
        }
        perfReport("soak-\(scenario.rawValue)", "iterations in 15 s", iterations)
        #expect(iterations > 0)
    }

    private func measureScenario(_ scenario: SidebarPerfScenario, sessionCount: Int) async throws {
        guard Self.isEnabled else { return }
        let harness = try await SidebarPerfHarness(sessionCount: sessionCount)
        defer { harness.close() }
        var runs: [SidebarInteractionMetrics] = []
        for _ in 0..<3 {
            try await harness.prepare(for: scenario)
            runs.append(try await harness.measure(scenario))
        }
        let median = runs.sorted { $0.total < $1.total }[1]
        let label = "\(scenario.rawValue) N=\(sessionCount)"
        perfReport(label, "total (median of 3)", median.total)
        perfReport(label, "longest main-thread gap (20 ms heartbeat)", median.longestGap)
        perfReport(label, "summed stall beyond heartbeat", median.stalled)
        perfReport(label, "store objectWillChange events", median.storeChanges)
        for (name, value) in median.extras { perfReport(label, name, value) }
        perfReport(label, "all 3 totals", runs.map { perfMilliseconds($0.total) }.joined(separator: ", "))
        #expect(runs.count == 3) // Record-only: the numbers above are the result.
    }
}

// MARK: - Scenarios

enum SidebarPerfScenario: String {
    case populate
    case typing
    case filters
    case selection
    case scroll
    case storeChange = "store-change"
    case preview
}

struct SidebarInteractionMetrics {
    var total: Duration
    var longestGap: Duration
    var stalled: Duration
    var storeChanges: Int
    var extras: [(String, String)]
}

// MARK: - Harness

/// `sessionCount` Claude Code sessions with real transcript files spread over 50 real project folders, listed by
/// a store with isolated settings and no background polling, shown in the real sidebar + detail layout.
@MainActor
final class SidebarPerfHarness {
    nonisolated static let projectFolderPrefix = "perfproj-"
    nonisolated static let projectCount = 50
    /// Spread over 14 days so the Recent filter keeps about half of the sessions.
    nonisolated static let updatedAtSpread: TimeInterval = 14 * 24 * 60 * 60

    let sandbox: DeletionSandbox
    let store: ConversationStore
    let conversations: [Conversation]
    let controls: SidebarPerfControls
    private let window: NSWindow
    private let hostingView: NSHostingView<AnyView>

    init(sessionCount: Int) async throws {
        let sandbox = try DeletionSandbox()
        self.sandbox = sandbox
        let sessionsFolder = sandbox.directory.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessionsFolder, withIntermediateDirectories: true)
        let projectFolders: [URL] = try (0..<Self.projectCount).map { index in
            let folder = sandbox.directory.appendingPathComponent(String(format: "\(Self.projectFolderPrefix)%02d", index))
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }
        // A small real Claude-style transcript, so the preview path reads real content.
        let transcript = """
        {"type":"user","message":{"role":"user","content":"Tidy up the sidebar rendering"},"timestamp":"2025-01-01T12:00:00Z"}
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Done. The sidebar now renders from the cached projection."}]},"timestamp":"2025-01-01T12:00:05Z"}

        """
        let now = Date.now
        let interval = Self.updatedAtSpread / Double(sessionCount)
        let conversations: [Conversation] = try (0..<sessionCount).map { index in
            let sessionID = UUID().uuidString.lowercased()
            let file = sessionsFolder.appendingPathComponent("\(sessionID).jsonl")
            try transcript.write(to: file, atomically: true, encoding: .utf8)
            return .fixture(
                provider: .claude,
                sessionID: sessionID,
                projectPath: projectFolders[index % Self.projectCount].path,
                title: "Session \(index): a typical prompt-length title for the sidebar",
                updatedAt: now.addingTimeInterval(-Double(index) * interval),
                sourceFile: file
            )
        }
        self.conversations = conversations
        let store = ConversationStore(
            adapters: [FileBackedConversationAdapter(provider: .claude, conversations: conversations)],
            userDefaults: sandbox.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
        self.store = store
        store.replaceConversations(on: .thisMac, with: conversations)
        // Custom titles on one session in ten, so title lookups go through the alias list as they do in use.
        for conversation in conversations.enumerated().filter({ $0.offset % 10 == 0 }).map(\.element) {
            store.rename(conversation, to: "Renamed \(conversation.suggestedTitle)")
        }

        controls = SidebarPerfControls()
        _ = NSApplication.shared
        hostingView = NSHostingView(rootView: AnyView(
            SidebarPerfBrowserHarness(store: store, controls: controls)
                .defaultAppStorage(sandbox.userDefaults)
        ))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        window.orderFrontRegardless()
        try await settle()
    }

    func close() {
        hostingView.rootView = AnyView(EmptyView())
        window.contentView = nil
        window.close()
        sandbox.remove()
    }

    // MARK: Preparing and measuring

    /// Puts the window in the scenario's starting state, which also undoes the previous run of the same scenario.
    func prepare(for scenario: SidebarPerfScenario) async throws {
        store.detachedCLIActivities = [:]
        controls.sessionSelection.clear()
        controls.recencyFilter = .all
        controls.providerFilter = .all
        switch scenario {
        case .populate:
            controls.searchText = ""
            store.replaceConversations(on: .thisMac, with: [])
        case .typing, .filters, .preview:
            controls.searchText = ""
        case .selection, .storeChange:
            // Searching for the shared project prefix matches every project and expands them all, the only way
            // to expand every project from outside the sidebar's private expansion state.
            controls.searchText = Self.projectFolderPrefix
        case .scroll:
            controls.searchText = Self.projectFolderPrefix
            if let scrollView = sidebarScrollView() {
                scrollView.contentView.scroll(to: .zero)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
        try await settle()
    }

    func measure(_ scenario: SidebarPerfScenario) async throws -> SidebarInteractionMetrics {
        var storeChanges = 0
        let objectWillChange = store.objectWillChange.sink { _ in storeChanges += 1 }
        defer { objectWillChange.cancel() }
        let heartbeat = MainThreadPerfHeartbeat()
        heartbeat.start()
        let clock = ContinuousClock()
        let start = clock.now
        let extras = try await run(scenario)
        let total = clock.now - start
        heartbeat.stop()
        return SidebarInteractionMetrics(
            total: total,
            longestGap: heartbeat.longestGap,
            stalled: heartbeat.stalledTime,
            storeChanges: storeChanges,
            extras: extras
        )
    }

    /// One scenario, from its prepared state. Returns scenario-specific extra report lines.
    func run(_ scenario: SidebarPerfScenario) async throws -> [(String, String)] {
        switch scenario {
        case .populate: try await runPopulate()
        case .typing: try await runTyping()
        case .filters: try await runFilterToggles()
        case .selection: try await runSelection()
        case .scroll: try await runScroll()
        case .storeChange: try await runStoreChange()
        case .preview: runPreview()
        }
    }

    private func runPopulate() async throws -> [(String, String)] {
        let apply = turn { store.replaceConversations(on: .thisMac, with: conversations) }
        try await pumpTurns(3)
        return [("replaceConversations + first render turn", perfMilliseconds(apply))]
    }

    private func runTyping() async throws -> [(String, String)] {
        let text = "session 1"
        var keystrokes: [Duration] = []
        for end in text.indices.map({ text.index(after: $0) }) {
            let prefix = String(text[..<end])
            keystrokes.append(turn { controls.searchText = prefix })
            try await oneRunloopTurn()
        }
        let clear = turn { controls.searchText = "" }
        try await oneRunloopTurn()
        let sorted = keystrokes.sorted()
        return [
            ("keystrokes", "\(keystrokes.count)"),
            ("per-keystroke min", perfMilliseconds(sorted.first ?? .zero)),
            ("per-keystroke median", perfMilliseconds(sorted[sorted.count / 2])),
            ("per-keystroke max", perfMilliseconds(sorted.last ?? .zero)),
            ("sum of keystroke turns", perfMilliseconds(keystrokes.reduce(.zero, +))),
            ("clearing the search", perfMilliseconds(clear)),
        ]
    }

    private func runFilterToggles() async throws -> [(String, String)] {
        let toRecent = turn { controls.recencyFilter = .recent }
        try await oneRunloopTurn()
        let backToAll = turn { controls.recencyFilter = .all }
        try await oneRunloopTurn()
        let providerOn = turn { controls.providerFilter = .only(.claude) }
        try await oneRunloopTurn()
        let providerOff = turn { controls.providerFilter = .all }
        try await oneRunloopTurn()
        return [
            ("recency All -> Recent", perfMilliseconds(toRecent)),
            ("recency Recent -> All", perfMilliseconds(backToAll)),
            ("provider filter on", perfMilliseconds(providerOn)),
            ("provider filter off", perfMilliseconds(providerOff)),
        ]
    }

    private func runSelection() async throws -> [(String, String)] {
        let orderedIDs = visibleConversationIDs()
        guard let first = orderedIDs.first, let last = orderedIDs.last else {
            return [("visible session rows", "none; selection skipped")]
        }
        // A plain click on the first row: the sidebar's click handler calls onSelectConversation, which the
        // browser answers with selectOnly and clearing the tab selection.
        let click = turn {
            controls.sessionSelection.selectOnly(first)
            store.selectTerminal(nil)
        }
        try await oneRunloopTurn()
        // Shift-click on the last row: the handler's range branch over the visible order.
        let shiftClick = turn { controls.sessionSelection.selectRange(to: last, in: orderedIDs) }
        try await oneRunloopTurn()
        let clear = turn { controls.sessionSelection.clear() }
        try await oneRunloopTurn()
        return [
            ("visible session rows", "\(orderedIDs.count)"),
            ("click first row", perfMilliseconds(click)),
            ("shift-click last row", perfMilliseconds(shiftClick)),
            ("clear selection", perfMilliseconds(clear)),
        ]
    }

    private func runScroll() async throws -> [(String, String)] {
        guard let scrollView = sidebarScrollView(), let documentView = scrollView.documentView else {
            return [("sidebar scroll view", "not found; scrolling skipped")]
        }
        let steps = 20
        let visibleHeight = scrollView.contentView.bounds.height
        let scrollableHeight = max(0, documentView.bounds.height - visibleHeight)
        var worstStep = Duration.zero
        for step in 0..<steps {
            let offset = scrollableHeight * CGFloat(step) / CGFloat(steps - 1)
            let stepTime = turn {
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: offset))
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
            worstStep = max(worstStep, stepTime)
            try await oneRunloopTurn()
        }
        return [
            ("document height", String(format: "%.0f pt (%.0f pt visible)", documentView.bounds.height, visibleHeight)),
            ("steps", "\(steps)"),
            ("worst step turn", perfMilliseconds(worstStep)),
        ]
    }

    private func runStoreChange() async throws -> [(String, String)] {
        guard let listedID = visibleConversationIDs().first else {
            return [("listed session", "none; store change skipped")]
        }
        let expanded = turn { store.detachedCLIActivities[listedID] = .working }
        try await pumpTurns(1)
        // The same tick with no search and every project collapsed, the state the app launches in.
        store.detachedCLIActivities = [:]
        controls.searchText = ""
        try await pumpTurns(3)
        let collapsed = turn { store.detachedCLIActivities[listedID] = .working }
        try await pumpTurns(1)
        return [
            ("turn with every project expanded (searching)", perfMilliseconds(expanded)),
            ("turn with projects collapsed, no search", perfMilliseconds(collapsed)),
        ]
    }

    private func runPreview() -> [(String, String)] {
        // The sidebar's plain-click path: no CLI runs this session, so the browser's onSelectConversation
        // selects only this row and clears the tab selection; the preview pane renders this turn.
        let conversation = conversations[0]
        let click = turn {
            if store.showRunningCLI(for: conversation) {
                controls.sessionSelection.clear()
            } else {
                controls.sessionSelection.selectOnly(conversation.id)
                store.selectTerminal(nil)
            }
        }
        // No pump turns: the transcript loads asynchronously and is excluded from this measurement.
        return [("click-to-preview turn", perfMilliseconds(click))]
    }

    // MARK: Window plumbing

    /// One user-visible turn: the change, then the layout and display it forces, synchronously.
    private func turn(_ change: () -> Void) -> Duration {
        ContinuousClock().measure {
            change()
            hostingView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }
    }

    private func oneRunloopTurn() async throws {
        try await Task.sleep(for: .milliseconds(1))
    }

    private func pumpTurns(_ count: Int) async throws {
        for _ in 0..<count {
            hostingView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            try await oneRunloopTurn()
        }
    }

    private func settle() async throws {
        for _ in 0..<8 {
            hostingView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    /// Session rows in the order the sidebar lists them with the current filters, all projects expanded.
    private func visibleConversationIDs() -> [String] {
        let filteredProjection = store.filteredSidebarProjection(
            providerFilter: controls.providerFilter,
            recencyFilter: controls.recencyFilter,
            searchText: controls.searchText
        )
        return HostProjectSection.sections(hosts: store.hosts, projects: filteredProjection.projects)
            .flatMap(\.projects)
            .flatMap { $0.conversations.map(\.id) }
    }

    /// The sidebar's backing NSScrollView: the leftmost scroll view in the window.
    private func sidebarScrollView() -> NSScrollView? {
        Self.descendants(ofType: NSScrollView.self, in: window.contentView)
            .min { first, second in
                first.convert(first.bounds, to: nil).minX < second.convert(second.bounds, to: nil).minX
            }
    }

    private static func descendants<ViewType: NSView>(ofType type: ViewType.Type, in view: NSView?) -> [ViewType] {
        guard let view else { return [] }
        return ((view as? ViewType).map { [$0] } ?? []) + view.subviews.flatMap { descendants(ofType: type, in: $0) }
    }
}

// MARK: - The hosted browser

/// The state ContentView and ConversationBrowserView keep in @State/@Binding, held where the test can drive it
/// through the same bindings the real views use.
@MainActor
final class SidebarPerfControls: ObservableObject {
    @Published var searchText = ""
    @Published var recencyFilter: SessionRecencyFilter = .all
    @Published var providerFilter: ConversationProviderFilter = .all
    @Published var sessionSelection = SessionMultiSelection()
}

/// ConversationBrowserView's layout and wiring without its Sparkle updater, which would check for updates inside
/// the test process. The projects are filtered exactly as ConversationBrowserView filters them.
private struct SidebarPerfBrowserHarness: View {
    @ObservedObject var store: ConversationStore
    @ObservedObject var controls: SidebarPerfControls

    var body: some View {
        let filteredProjection = store.filteredSidebarProjection(
            providerFilter: controls.providerFilter,
            recencyFilter: controls.recencyFilter,
            searchText: controls.searchText
        )
        ResizableSidebarLayout(isSidebarHidden: false) {
            ConversationSidebarView(
                store: store,
                searchText: $controls.searchText,
                recencyFilter: $controls.recencyFilter,
                providerFilter: $controls.providerFilter,
                sessionSelection: $controls.sessionSelection,
                projects: filteredProjection.projects,
                allSessionCount: filteredProjection.allSessionCount,
                recentSessionCount: filteredProjection.recentSessionCount,
                onCheckForUpdates: {},
                onNewSession: {},
                onNewSessionOnHost: { _ in },
                onSelectConversation: { conversation in
                    if store.showRunningCLI(for: conversation) {
                        controls.sessionSelection.clear()
                    } else {
                        controls.sessionSelection.selectOnly(conversation.id)
                        store.selectTerminal(nil)
                    }
                },
                onRenameConversation: { _ in },
                onRenameProject: { _ in },
                onRequestDeletion: { _ in }
            )
        } detail: {
            WorkspaceDetailView(
                store: store,
                sessionSelection: controls.sessionSelection,
                isSidebarHidden: false,
                onRename: { _ in },
                onCloseTerminal: { _ in },
                onDelete: { _ in }
            )
        }
    }
}

// MARK: - Heartbeat

/// Ticks on the main queue every 20 ms and records how late each tick came: a late tick is time the main thread
/// spent on something else, which the user sees as a frozen window.
@MainActor
final class MainThreadPerfHeartbeat {
    let interval: Duration = .milliseconds(20)
    private var timer: DispatchSourceTimer?
    private var lastTick: ContinuousClock.Instant?
    private(set) var longestGap: Duration = .zero
    private(set) var stalledTime: Duration = .zero
    private(set) var tickCount = 0

    func start() {
        lastTick = ContinuousClock.now
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(20), repeating: .milliseconds(20), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        tick()
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let now = ContinuousClock.now
        if let lastTick {
            let gap = now - lastTick
            longestGap = max(longestGap, gap)
            if gap > interval { stalledTime += gap - interval }
        }
        lastTick = now
        tickCount += 1
    }
}

// MARK: - Reporting

func perfMilliseconds(_ value: Duration) -> String {
    let milliseconds = Double(value.components.seconds) * 1_000 + Double(value.components.attoseconds) / 1e15
    return String(format: "%.1f ms", milliseconds)
}

func perfReport(_ scenario: String, _ name: String, _ value: Duration) {
    perfReport(scenario, name, perfMilliseconds(value))
}

func perfReport(_ scenario: String, _ name: String, _ value: some CustomStringConvertible) {
    let line = "Perf | \(scenario) | \(name) | \(value)"
    print(line)
    appendToPerfLog(line)
}

/// Where `JUSTSESSIONS_PERF_LOG_DIR` asks for the log and pid files; nil leaves the output on stdout alone.
private func perfLogDirectory() -> URL? {
    ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF_LOG_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
}

private func appendToPerfLog(_ line: String) {
    guard let directory = perfLogDirectory() else { return }
    let log = directory.appendingPathComponent("interactions.log")
    guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else { return }
    if !FileManager.default.fileExists(atPath: log.path) {
        FileManager.default.createFile(atPath: log.path, contents: nil)
    }
    guard let handle = try? FileHandle(forWritingTo: log) else { return }
    defer { try? handle.close() }
    _ = try? handle.seekToEnd()
    try? handle.write(contentsOf: Data((line + "\n").utf8))
}
