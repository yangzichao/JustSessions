import AppKit
import Darwin
import Foundation
import ObjectiveC
import SwiftTerm
import SwiftUI
import Testing

@testable import JustSessions

/// How long a keystroke takes to show in a quiet SwiftTerm tab while other tabs flood output, on the real
/// pseudo-terminal path: the quiet tab runs `cat`, which echoes what is typed, and each flooding tab runs a script
/// that prints lines as fast as it can, or at a set rate: 25,000 lines a second is about a 2 MB/s build log. Visible
/// flooders draw; hidden ones are batched as the workspace batches them.
/// Reports `Perf | <scenario> | <metric> | <value>` lines for each keystroke's time until its bytes reach the quiet
/// terminal (`dataReceived`) and until the quiet view next draws, as p50, p95, and worst; plus the flooders' throughput
/// and the main thread's longest gap. With maps following growing sessions, that many conversation-map columns show
/// beside the terminals (PERF-89, PERF-90), each following a Codex file that grows by a 1 KB record every 100 ms.
/// See docs/development/performance.md.
///
///     JUSTSESSIONS_PERF=1 swift test -c release --filter TerminalFairnessMeasurements
@MainActor
@Suite(.serialized)
struct TerminalFairnessMeasurements {
    struct Scenario: CustomStringConvertible {
        let visibleFlooders: Int
        let hiddenFlooders: Int
        /// Lines a second each flooder prints; nil for as fast as it can, about 50 MB/s. A fast build log is about
        /// 2 MB/s: 25,000 of these 76-byte lines a second.
        var linesPerSecond: Int? = nil
        /// Conversation-map columns shown with the map on, each following its own growing session file.
        var mapsFollowingGrowingSessions = 0
        var description: String {
            let rate = linesPerSecond.map { " at \($0.formatted()) lines/s each" } ?? " as fast as they can"
            let maps = mapsFollowingGrowingSessions > 0 ? ", with \(mapsFollowingGrowingSessions) maps following growing sessions" : ""
            switch (visibleFlooders, hiddenFlooders) {
            case (0, 0): return "quiet tab alone\(maps)"
            default: return "quiet tab beside \(visibleFlooders) visible and \(hiddenFlooders) hidden flooding tabs\(rate)\(maps)"
            }
        }
    }

    static let scenarios = [
        Scenario(visibleFlooders: 0, hiddenFlooders: 0),
        Scenario(visibleFlooders: 1, hiddenFlooders: 0),
        Scenario(visibleFlooders: 3, hiddenFlooders: 0),
        Scenario(visibleFlooders: 0, hiddenFlooders: 5),
        Scenario(visibleFlooders: 1, hiddenFlooders: 5),
        Scenario(visibleFlooders: 1, hiddenFlooders: 5, linesPerSecond: 25_000),
        Scenario(visibleFlooders: 1, hiddenFlooders: 5, linesPerSecond: 25_000, mapsFollowingGrowingSessions: 2),
        Scenario(visibleFlooders: 1, hiddenFlooders: 5, linesPerSecond: 5_000),
    ]

    @Test func keystrokesWhileOtherTabsFlood() async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        for scenario in Self.scenarios {
            let bench = try FairnessBench(scenario: scenario)
            let result = try await bench.run(keystrokes: 60, interval: .milliseconds(50))
            bench.tearDown()
            let label = scenario.description
            perfReport(label, "keystrokes echoed", "\(result.echoed) of \(result.sent)")
            perfReport(label, "input to bytes received: p50 / p95 / worst", result.receivedLatency.summary)
            perfReport(label, "input to next draw of the quiet tab: p50 / p95 / worst", result.drawLatency.summary)
            perfReport(label, "longest main-thread gap", perfMilliseconds(result.longestMainThreadGap))
            perfReport(label, "flood lines parsed, all flooders", result.floodLines.formatted())
            perfReport(label, "process CPU % of one core", String(format: "%.0f", result.cpuPercent))
            if scenario.mapsFollowingGrowingSessions > 0 {
                perfReport(label, "map outline reads", result.mapReadCounts.map(String.init).joined(separator: ", "))
                // A map that never read measured nothing.
                #expect(result.mapReadCounts.allSatisfy { $0 > 0 }, "\(label): a map never read its session")
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        #expect(!Self.scenarios.isEmpty)  // Record-only: the numbers above are the result.
    }
}

private struct Latencies {
    var values: [Duration] = []

    var summary: String {
        guard !values.isEmpty else { return "none" }
        let sorted = values.sorted()
        func at(_ fraction: Double) -> Duration { sorted[min(sorted.count - 1, Int(Double(sorted.count) * fraction))] }
        return "\(perfMilliseconds(at(0.5))) / \(perfMilliseconds(at(0.95))) / \(perfMilliseconds(sorted[sorted.count - 1]))"
    }
}

private struct FairnessResult {
    let sent: Int
    let echoed: Int
    let receivedLatency: Latencies
    let drawLatency: Latencies
    let longestMainThreadGap: Duration
    let floodLines: Int
    let cpuPercent: Double
    let mapReadCounts: [Int]
}

@MainActor
private final class FairnessBench {
    private static let frame = NSRect(x: 100, y: 100, width: 1000, height: 650)
    private let scenario: TerminalFairnessMeasurements.Scenario
    private let window: NSWindow
    private let folder: URL
    private let quiet: SelectableTerminalView
    private var flooders: [SelectableTerminalView] = []
    private let appearanceStore: TerminalAppearanceStore
    private let themeStore: AppThemeStore
    private let settings: IsolatedUserDefaults
    private var mapModels: [ConversationOutlineModel] = []
    private var mapFiles: [URL] = []
    private var mapGrowth: Task<Void, Never>?

    init(scenario: TerminalFairnessMeasurements.Scenario) throws {
        _ = NSApplication.shared
        self.scenario = scenario
        settings = try IsolatedUserDefaults()
        appearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        folder = try makeTemporaryDirectory()
        window = NSWindow(contentRect: Self.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: Self.frame)
        window.orderFrontRegardless()
        // Visible tabs share the window side by side, as split panes do.
        let visibleCount = 1 + scenario.visibleFlooders
        // The maps take the window's right, as each column takes its tab's.
        let mapsWidth = CGFloat(scenario.mapsFollowingGrowingSessions) * ConversationMapMetrics.columnWidth
        let paneWidth = (Self.frame.width - mapsWidth) / CGFloat(visibleCount)
        func pane(_ index: Int) -> NSRect { NSRect(x: paneWidth * CGFloat(index), y: 0, width: paneWidth, height: Self.frame.height) }
        quiet = Self.makeView(frame: pane(0), appearanceStore: appearanceStore, themeStore: themeStore)
        window.contentView?.addSubview(quiet)
        for index in 0..<scenario.visibleFlooders {
            let view = Self.makeView(frame: pane(index + 1), appearanceStore: appearanceStore, themeStore: themeStore)
            window.contentView?.addSubview(view)
            flooders.append(view)
        }
        for _ in 0..<scenario.hiddenFlooders {
            let view = Self.makeView(frame: pane(0), appearanceStore: appearanceStore, themeStore: themeStore)
            view.alphaValue = 0
            view.setWorkspaceActive(false)
            window.contentView?.addSubview(view)
            flooders.append(view)
        }
        if scenario.mapsFollowingGrowingSessions > 0 { try addMaps(width: mapsWidth) }
    }

    /// Columns as `TerminalWorkspaceView` shows them, with the map on, each linked to a Codex file of 200 messages.
    private func addMaps(width: CGFloat) throws {
        settings.userDefaults.set(true, forKey: ConversationMapVisibility.userDefaultsKey)
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        var columns: [ConversationMapColumn] = []
        for index in 0..<scenario.mapsFollowingGrowingSessions {
            let file = folder.appendingPathComponent("map-\(index).jsonl")
            try TranscriptPagingFixture.data(count: 200).write(to: file)
            let model = ConversationOutlineModel()
            mapFiles.append(file)
            mapModels.append(model)
            columns.append(
                ConversationMapColumn(
                    model: model, conversation: .fixture(provider: .codex, sessionID: "map-\(index)", sourceFile: file),
                    provider: .codex, isShown: true, store: store, hover: ConversationMapHover()))
        }
        let host = NSHostingView(
            rootView: HStack(spacing: 0) {
                ForEach(columns.indices, id: \.self) { columns[$0].equatable() }
            }
            .defaultAppStorage(settings.userDefaults)
            // macOS reports no occlusion to a test process.
            .environment(\.ignoresWindowOcclusion, true))
        host.frame = NSRect(x: Self.frame.width - width, y: 0, width: width, height: Self.frame.height)
        window.contentView?.addSubview(host)
    }

    /// Appends a 1 KB Codex reply to each map's file every 100 ms, off the main thread.
    private func growMapSessions() {
        let files = mapFiles
        guard !files.isEmpty else { return }
        mapGrowth = Task.detached(priority: .utility) {
            let text = String(repeating: "Growing reply text. ", count: 45)
            var record = 0
            while !Task.isCancelled {
                let line =
                    #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Reply \#(record): \#(text)"}]}}"#
                    + "\n"
                for file in files {
                    guard let handle = try? FileHandle(forWritingTo: file) else { continue }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: Data(line.utf8))
                    try? handle.close()
                }
                record += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private static func makeView(frame: NSRect, appearanceStore: TerminalAppearanceStore, themeStore: AppThemeStore)
        -> SelectableTerminalView
    {
        let view = TerminalEngine.swiftTerm.makeTabTerminalView(frame: frame, appearanceStore: appearanceStore, themeStore: themeStore)
        return view as! SelectableTerminalView
    }

    func run(keystrokes: Int, interval: Duration) async throws -> FairnessResult {
        start(quiet, command: "exec /bin/cat")
        let floodScript = folder.appendingPathComponent("flood.pl")
        // With a rate, prints in bursts of a hundredth of a second's worth, then sleeps the rest of the hundredth.
        let perSecond = scenario.linesPerSecond ?? 0
        try #"""
        use Time::HiRes qw(sleep time);
        $| = 1;
        my $i = 0;
        my $burst = int(\#(perSecond) / 100);
        while (1) {
            my $started = time();
            my $n = $burst > 0 ? $burst : 1000;
            for (1..$n) {
                printf("\e[3%dm%08d  %s\e[0m\r\n", 1 + $i % 6, $i, "x" x 60);
                $i++;
            }
            if ($burst > 0) {
                my $left = 0.01 - (time() - $started);
                sleep($left) if $left > 0;
            }
        }
        """#.write(to: floodScript, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(500))
        let probe = QuietTerminalProbe(view: quiet)
        probe.install()
        defer { probe.uninstall() }
        let floodCounter = FloodLineCounter(views: flooders)
        for flooder in flooders { start(flooder, command: "exec /usr/bin/perl flood.pl") }
        growMapSessions()
        // Let the flood get going before typing.
        try await Task.sleep(for: .milliseconds(700))

        let heartbeat = MainThreadPerfHeartbeat()
        heartbeat.start()
        let cpuStart = fairnessProcessCPUSeconds()
        let start = ContinuousClock.now
        var sent = 0
        for index in 0..<keystrokes {
            let marker = String(format: "k%03d", index)
            probe.expect(marker)
            // One marker a line, so none straddles a wrap at the pane's width.
            quiet.send(txt: marker + "\r\n")
            sent += 1
            try await Task.sleep(for: interval)
        }
        // Give the last keystrokes time to show.
        try await Task.sleep(for: .seconds(1))
        let elapsed = ContinuousClock.now - start
        heartbeat.stop()
        let cpu = fairnessProcessCPUSeconds() - cpuStart
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let (received, drawn, echoed) = probe.results()
        mapGrowth?.cancel()
        return FairnessResult(
            sent: sent, echoed: echoed, receivedLatency: received, drawLatency: drawn,
            longestMainThreadGap: heartbeat.longestGap, floodLines: floodCounter.lines, cpuPercent: cpu / seconds * 100,
            mapReadCounts: mapModels.map(\.readCount)
        )
    }

    private func start(_ view: SelectableTerminalView, command: String) {
        view.startProcess(
            executable: "/bin/sh",
            args: ["-c", "stty raw -echo; \(command)"],
            environment: ["HOME=\(folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"],
            execName: nil,
            currentDirectory: folder.path
        )
    }

    func tearDown() {
        for view in [quiet] + flooders {
            let processID = view.processID
            if processID > 0 { kill(processID, SIGHUP) }
            view.terminate()
            ClosedTabProcessReaper.reapOnceExited(processID)
            view.removeFromSuperview()
        }
        mapGrowth?.cancel()
        for model in mapModels { model.release() }
        window.contentView = nil
        window.close()
        try? FileManager.default.removeItem(at: folder)
        settings.removeSuite()
    }
}

/// Times each marker typed into the quiet terminal: when it shows on the terminal's screen, read every 2 ms from the
/// main queue, and when the view next draws after that. The 2 ms reads run on the main thread, so a stall there delays
/// them as it delays the display; that is the delay a person would see. `draw(_:)` is hooked on SwiftTerm's view class
/// for every view, keeping only the quiet view's draws.
@MainActor
private final class QuietTerminalProbe {
    private let view: SelectableTerminalView
    private var pending: [(marker: String, sentAt: ContinuousClock.Instant)] = []
    private var awaitingDraw: [ContinuousClock.Instant] = []
    private var received = Latencies()
    private var drawn = Latencies()
    private var echoed = 0
    private var timer: DispatchSourceTimer?
    nonisolated(unsafe) private static var current: QuietTerminalProbe?
    private static var originalDraw: IMP?

    init(view: SelectableTerminalView) { self.view = view }

    func expect(_ marker: String) { pending.append((marker, .now)) }

    func results() -> (Latencies, Latencies, Int) { (received, drawn, echoed) }

    /// The quiet terminal's screen, where `cat` echoes what was typed.
    private var screenText: String {
        let terminal = view.getTerminal()
        return (0..<terminal.rows).compactMap { terminal.getLine(row: $0)?.translateToString(trimRight: true) }.joined(separator: "\n")
    }

    private func poll() {
        guard let first = pending.first else { return }
        let now = ContinuousClock.now
        let text = screenText
        while let next = pending.first, text.contains(next.marker) {
            received.values.append(now - next.sentAt)
            awaitingDraw.append(next.sentAt)
            echoed += 1
            pending.removeFirst()
        }
        _ = first
    }

    private func drew() {
        guard !awaitingDraw.isEmpty else { return }
        let now = ContinuousClock.now
        for sentAt in awaitingDraw { drawn.values.append(now - sentAt) }
        awaitingDraw.removeAll()
    }

    func install() {
        Self.current = self
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(2), leeway: .microseconds(200))
        timer.setEventHandler { MainActor.assumeIsolated { Self.current?.poll() } }
        timer.resume()
        self.timer = timer
        if let method = class_getInstanceMethod(SwiftTerm.TerminalView.self, #selector(NSView.draw(_:))) {
            typealias Draw = @convention(c) (NSView, Selector, NSRect) -> Void
            let original = method_getImplementation(method)
            let callOriginal = unsafeBitCast(original, to: Draw.self)
            let hooked: @convention(block) (NSView, NSRect) -> Void = { view, rect in
                callOriginal(view, #selector(NSView.draw(_:)), rect)
                MainActor.assumeIsolated {
                    if let probe = Self.current, probe.view === view { probe.drew() }
                }
            }
            method_setImplementation(method, imp_implementationWithBlock(hooked))
            Self.originalDraw = original
        }
    }

    func uninstall() {
        timer?.cancel()
        timer = nil
        if let originalDraw = Self.originalDraw,
            let method = class_getInstanceMethod(SwiftTerm.TerminalView.self, #selector(NSView.draw(_:)))
        {
            method_setImplementation(method, originalDraw)
        }
        Self.originalDraw = nil
        Self.current = nil
    }
}

/// How many lines the flooding terminals got through: each flooder prints a running line number, and the largest one
/// on a flooder's screen at the end is how far it got. Lines a flooder printed but the terminal hadn't parsed yet
/// aren't counted, which is the point: this is what reached the screen.
@MainActor
private final class FloodLineCounter {
    private let views: [SelectableTerminalView]
    init(views: [SelectableTerminalView]) { self.views = views }
    /// Lines parsed across every flooder, from the largest line number on each screen.
    var lines: Int {
        views.reduce(0) { total, view in
            let terminal = view.getTerminal()
            let numbers = (0..<terminal.rows).compactMap { row -> Int? in
                guard let text = terminal.getLine(row: row)?.translateToString(trimRight: true),
                    let range = text.firstRange(of: /\d{8}/)
                else { return nil }
                return Int(text[range])
            }
            return total + (numbers.max().map { $0 + 1 } ?? 0)
        }
    }
}

private func fairnessProcessCPUSeconds() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
        + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
}
