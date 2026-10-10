import AppKit
import Darwin
import Foundation
import GhosttyTerminal
import ObjectiveC
import SwiftTerm
import Testing
@testable import JustSessions

/// The same controlled output through a Ghostty tab and a SwiftTerm tab, in a window ordered front. Each tab runs a
/// script through its own `startProcess`, so the output comes from a pseudo-terminal as a CLI's does; it starts no CLI
/// sessions. Records process CPU as a percentage of one core, the main thread's CPU, its longest gap, frames drawn,
/// and memory; see docs/development/performance.md. Each test runs every engine three times, alternating which goes
/// first, so background load falls on both alike.
///
///     JUSTSESSIONS_PERF=1 swift test -c release --filter TerminalEngineMeasurements
///
/// With `JUSTSESSIONS_PERF_SAMPLE_DIR` set, the repaint test also records a 5-second `sample` profile of each engine
/// there, in a run of its own that isn't measured.
@MainActor
@Suite(.serialized)
struct TerminalEngineMeasurements {
    private static let runCount = 3

    /// Workload 1: one visible tab, a TUI-style repaint of 8 rows at 30 frames a second for 5 seconds.
    @Test func tuiRepaint() async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        let runs = try await Self.alternatingRuns(of: TerminalEngine.allCases) { engine in
            try await Self.measureRepaint(engine: engine, tabCount: 1)
        }
        for engine in TerminalEngine.allCases {
            Self.report("repaint, 1 tab", engine, runs[engine] ?? [])
        }
        guard let directory = ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF_SAMPLE_DIR"] else { return }
        for engine in TerminalEngine.allCases {
            let file = URL(fileURLWithPath: directory).appendingPathComponent("sample-repaint-\(engine.rawValue).txt")
            _ = try await Self.measureRepaint(engine: engine, tabCount: 1, seconds: 7, sampleFile: file)
            perfReport("repaint, 1 tab", "\(engine.displayName) sample profile", file.path)
        }
    }

    /// Workload 2: one visible tab, about 20 MB of colored log lines with some truecolor and CJK.
    @Test func bulkStream() async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        let stream = try BulkStream()
        defer { stream.remove() }
        let runs = try await Self.alternatingRuns(of: TerminalEngine.allCases) { engine in
            try await Self.measureBulk(engine: engine, stream: stream)
        }
        for engine in TerminalEngine.allCases {
            Self.report("bulk \(stream.megabytes) MB, \(stream.lineCount) lines, 1 tab", engine, runs[engine] ?? [])
        }
    }

    /// Workload 3: the repaint in every tab, with one tab shown and the rest hidden as a workspace hides them.
    @Test(arguments: [5, 10])
    func hiddenTabsRepaint(tabCount: Int) async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        let runs = try await Self.alternatingRuns(of: TerminalEngine.allCases) { engine in
            try await Self.measureRepaint(engine: engine, tabCount: tabCount)
        }
        for engine in TerminalEngine.allCases {
            Self.report("repaint, \(tabCount) tabs, 1 shown", engine, runs[engine] ?? [])
        }
    }

    /// Workload 4: memory before any tab, with 10 idle tabs, and once every tab's scrollback is full after the bulk
    /// stream, so each tab's share is a tenth of the change. Each engine keeps its shipped scrollback; one SwiftTerm
    /// case raises it to 10,000 lines.
    ///
    /// One run per process: memory the process freed and then uses again is not always counted again, so a later run
    /// in the same process reads too low. Run each case in a process of its own, three times, alternating the cases:
    ///
    ///     JUSTSESSIONS_PERF=1 JUSTSESSIONS_PERF_MEMORY_CASE=ghostty swift test -c release --filter TerminalEngineMeasurements/memory
    ///
    /// The cases are `ghostty`, `swiftTerm`, and `swiftTerm10k`.
    @Test func memory() async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        let caseName = ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF_MEMORY_CASE"]
        guard let scrollbackCase = ScrollbackCase.all.first(where: { $0.name == caseName }) else {
            perfReport("memory", "skipped", "set JUSTSESSIONS_PERF_MEMORY_CASE to one of \(ScrollbackCase.all.map(\.name))")
            return
        }
        let stream = try BulkStream()
        defer { stream.remove() }
        let run = try await Self.measureMemory(scrollbackCase, stream: stream)
        let scenario = "memory, \(scrollbackCase)"
        for (name, measure) in [("footprint", \MemoryUsage.footprint), ("resident", \MemoryUsage.resident)] {
            let figures = run.megabytes(measure)
            perfReport(scenario, "\(name) before tabs, MB", String(format: "%.1f", figures.before))
            perfReport(scenario, "\(name) with 10 idle tabs, MB", String(format: "%.1f", figures.idle))
            perfReport(scenario, "\(name) per idle tab, MB", String(format: "%.1f", figures.perIdleTab))
            perfReport(scenario, "\(name) after the bulk stream in every tab, MB", String(format: "%.1f", figures.afterBulk))
            perfReport(scenario, "\(name) added per full tab, MB", String(format: "%.1f", figures.perFullTab))
        }
        perfReport(scenario, "scrollback rows kept", run.keptRows)
        perfReport(scenario, "columns", run.columns)
    }

    /// Runs `measure` for each case `runCount` times, a round at a time, reversing the order every other round.
    private static func alternatingRuns<Case: Hashable, Run>(
        of cases: [Case],
        _ measure: @MainActor (Case) async throws -> Run
    ) async throws -> [Case: [Run]] {
        var runs: [Case: [Run]] = [:]
        for round in 0..<runCount {
            for item in round.isMultiple(of: 2) ? cases : cases.reversed() {
                runs[item, default: []].append(try await measure(item))
            }
        }
        return runs
    }

    // MARK: - Runs

    private static func measureRepaint(
        engine: TerminalEngine,
        tabCount: Int,
        seconds: Int = 5,
        sampleFile: URL? = nil
    ) async throws -> EngineRun {
        let bench = try EngineBench(engine: engine)
        defer { bench.tearDown() }
        let frameCount = seconds * 30
        try RepaintScript.write(to: bench.folder)
        bench.addTabs(tabCount)
        for tab in bench.tabs {
            bench.start(tab, command: "exec /usr/bin/perl repaint.pl go \(frameCount)")
        }
        try await bench.waitUntilLaidOut()
        let meter = EngineMeter(engine: engine)
        meter.start(tabs: bench.tabs)
        bench.signalGo()
        let sampler = try sampleFile.map(Self.startSampling)
        try await Task.sleep(for: .seconds(seconds))
        let lastFrame = "frame \(frameCount - 1)"
        try await waitUntil(timeout: .seconds(30)) { visibleText(of: bench.tabs[0]).contains(lastFrame) }
        let run = meter.stop()
        if let sampler { try await waitForExit(of: sampler) }
        return run
    }

    private static func measureBulk(engine: TerminalEngine, stream: BulkStream) async throws -> EngineRun {
        let bench = try EngineBench(engine: engine)
        defer { bench.tearDown() }
        bench.addTabs(1)
        bench.startStreaming(stream)
        try await bench.waitUntilLaidOut()
        let meter = EngineMeter(engine: engine)
        meter.start(tabs: bench.tabs)
        bench.signalGo()
        try await waitUntil(timeout: .seconds(180)) { bench.hasShownEverything(of: stream) }
        return meter.stop()
    }

    private static func measureMemory(_ scrollbackCase: ScrollbackCase, stream: BulkStream) async throws -> MemoryRun {
        let bench = try EngineBench(engine: scrollbackCase.engine)
        defer { bench.tearDown() }
        let before = try await settledMemory()
        bench.addTabs(10)
        if let scrollback = scrollbackCase.swiftTermScrollback {
            for case let view as SelectableTerminalView in bench.tabs { view.changeScrollback(scrollback) }
        }
        bench.startStreaming(stream)
        try await bench.waitUntilLaidOut()
        let idle = try await settledMemory()
        bench.signalGo()
        try await waitUntil(timeout: .seconds(180)) { bench.hasShownEverything(of: stream) }
        let afterBulk = try await settledMemory()
        let keptRows = stream.rowsKept(in: allText(of: bench.tabs[0]))
        return MemoryRun(
            before: before,
            idle: idle,
            afterBulk: afterBulk,
            tabCount: 10,
            keptRows: keptRows,
            columns: gridColumns(of: bench.tabs[0])
        )
    }

    // MARK: - Profile

    private static func startSampling(into file: URL) throws -> Process {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let sampler = Process()
        sampler.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
        sampler.arguments = [String(getpid()), "5", "-file", file.path]
        sampler.standardOutput = FileHandle.nullDevice
        sampler.standardError = FileHandle.nullDevice
        try sampler.run()
        return sampler
    }

    private static func waitForExit(of process: Process) async throws {
        try await waitUntil(timeout: .seconds(120)) { !process.isRunning }
    }

    // MARK: - Reporting

    private static func report(_ scenario: String, _ engine: TerminalEngine, _ runs: [EngineRun]) {
        let name = engine.displayName
        perfReport(scenario, "\(name) seconds", summary(runs.map(\.seconds), digits: 2))
        perfReport(scenario, "\(name) CPU % of one core", summary(runs.map(\.cpuPercent), digits: 1))
        perfReport(scenario, "\(name) main thread CPU % of one core", summary(runs.map(\.mainThreadPercent), digits: 1))
        perfReport(scenario, "\(name) longest main-thread gap, ms", summary(runs.map(\.longestGapMilliseconds), digits: 1))
        perfReport(scenario, "\(name) frames drawn", summary(runs.map { Double($0.framesDrawn) }, digits: 0))
    }

    /// The median, the lowest and highest, and each run in the order it ran.
    private static func summary(_ values: [Double], digits: Int) -> String {
        guard !values.isEmpty else { return "no runs" }
        let format = "%.\(digits)f"
        let sorted = values.sorted()
        let median = String(format: format, sorted[sorted.count / 2])
        let range = "min=\(String(format: format, sorted[0])) max=\(String(format: format, sorted[sorted.count - 1]))"
        return "median=\(median) \(range) runs=[\(values.map { String(format: format, $0) }.joined(separator: ", "))]"
    }
}

// MARK: - Cases and results

private struct ScrollbackCase: CustomStringConvertible {
    /// What `JUSTSESSIONS_PERF_MEMORY_CASE` names it.
    let name: String
    let engine: TerminalEngine
    /// Nil keeps the engine's shipped scrollback: SwiftTerm's 500 lines, or Ghostty's default 10 MB limit.
    let swiftTermScrollback: Int?

    static let all = [
        ScrollbackCase(name: "ghostty", engine: .ghostty, swiftTermScrollback: nil),
        ScrollbackCase(name: "swiftTerm", engine: .swiftTerm, swiftTermScrollback: nil),
        ScrollbackCase(name: "swiftTerm10k", engine: .swiftTerm, swiftTermScrollback: 10_000),
    ]

    var description: String {
        switch swiftTermScrollback {
        case nil: "\(engine.displayName), shipped scrollback"
        case let lines?: "\(engine.displayName), scrollback \(lines) lines"
        }
    }
}

private struct EngineRun {
    let seconds: Double
    let cpuPercent: Double
    let mainThreadPercent: Double
    let longestGapMilliseconds: Double
    let framesDrawn: Int
}

private struct MemoryRun {
    let before: MemoryUsage
    let idle: MemoryUsage
    let afterBulk: MemoryUsage
    let tabCount: Int
    let keptRows: Int
    let columns: Int

    /// Each figure in MB, for the footprint or resident memory.
    func megabytes(_ measure: KeyPath<MemoryUsage, UInt64>) -> MemoryFigures {
        let before = Double(before[keyPath: measure]) / 1_048_576
        let idle = Double(idle[keyPath: measure]) / 1_048_576
        let afterBulk = Double(afterBulk[keyPath: measure]) / 1_048_576
        return MemoryFigures(
            before: before,
            idle: idle,
            perIdleTab: (idle - before) / Double(tabCount),
            afterBulk: afterBulk,
            perFullTab: (afterBulk - idle) / Double(tabCount)
        )
    }
}

private struct MemoryFigures {
    let before: Double
    let idle: Double
    let perIdleTab: Double
    let afterBulk: Double
    let perFullTab: Double
}

// MARK: - Bench

/// Tabs of one engine in a window ordered front, each running a shell command on its own pseudo-terminal. Each command
/// waits for the `go` file, so output starts when the measurement does.
@MainActor
private final class EngineBench {
    static let frame = NSRect(x: 0, y: 0, width: 1000, height: 650)

    let engine: TerminalEngine
    let folder: URL
    private(set) var tabs: [any TabTerminalView] = []
    private let window: NSWindow
    private let settings: IsolatedUserDefaults
    private let appearanceStore: TerminalAppearanceStore
    private let themeStore: AppThemeStore

    init(engine: TerminalEngine) throws {
        _ = NSApplication.shared
        self.engine = engine
        settings = try IsolatedUserDefaults()
        appearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        folder = try makeTemporaryDirectory()
        window = NSWindow(contentRect: Self.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: Self.frame)
        window.orderFrontRegardless()
    }

    /// The first tab is shown; the rest are hidden, as the workspace hides a tab that isn't on screen.
    func addTabs(_ count: Int) {
        for index in 0..<count {
            let view = engine.makeTabTerminalView(frame: Self.frame, appearanceStore: appearanceStore, themeStore: themeStore)
            view.autoresizingMask = [.width, .height]
            let isShown = index == 0
            view.alphaValue = isShown ? 1 : 0
            view.setWorkspaceActive(isShown)
            window.contentView?.addSubview(view)
            tabs.append(view)
        }
    }

    func start(_ tab: any TabTerminalView, command: String) {
        tab.startProcess(
            executable: "/bin/sh",
            args: ["-c", "stty raw -echo; \(command)"],
            environment: ["HOME=\(folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"],
            execName: nil,
            currentDirectory: folder.path
        )
    }

    /// Ghostty lays a new terminal out twice, first at a provisional size; this waits until every grid stays put, then
    /// lets the window settle.
    func waitUntilLaidOut() async throws {
        let ghosttyTabs = tabs.compactMap { $0 as? GhosttyTabTerminalView }
        var lastViewports = ghosttyTabs.map(\.viewport)
        var stableSince = ContinuousClock.now
        let deadline = ContinuousClock.now + .seconds(15)
        while !ghosttyTabs.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
            let viewports = ghosttyTabs.map(\.viewport)
            if viewports != lastViewports {
                lastViewports = viewports
                stableSince = .now
            } else if !viewports.contains(nil), ContinuousClock.now - stableSince > .milliseconds(300) {
                break
            }
        }
        try await Task.sleep(for: .milliseconds(500))
    }

    func signalGo() {
        FileManager.default.createFile(atPath: folder.appendingPathComponent("go").path, contents: nil)
    }

    /// Every tab writes the stream once `go` appears.
    func startStreaming(_ stream: BulkStream) {
        for (index, tab) in tabs.enumerated() {
            start(tab, command: stream.command(touchingWhenWritten: "done-\(index)"))
        }
    }

    /// Every tab's command finished writing, its terminal parsed all of it, and its screen has the last line.
    func hasShownEverything(of stream: BulkStream) -> Bool {
        tabs.indices.allSatisfy { index in
            let tab = tabs[index]
            guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("done-\(index)").path) else { return false }
            if let ghosttyView = tab as? GhosttyTabTerminalView, ghosttyView.outputBackpressure.unparsedByteCount > 0 {
                return false
            }
            return visibleText(of: tab).contains(BulkStream.lastLine)
        }
    }

    func tearDown() {
        for tab in tabs {
            let processID = tab.processID
            if processID > 0 { kill(processID, SIGHUP) }
            tab.terminate()
            ClosedTabProcessReaper.reapOnceExited(processID)
            tab.removeFromSuperview()
        }
        window.contentView = nil
        window.close()
        try? FileManager.default.removeItem(at: folder)
        settings.removeSuite()
    }
}

/// What the shown tab's screen holds now, without its scrollback.
@MainActor
private func visibleText(of tab: any TabTerminalView) -> String {
    switch tab {
    case let ghosttyView as GhosttyTabTerminalView:
        return ghosttyView.inMemorySession.readViewportText() ?? ""
    case let swiftTermView as SelectableTerminalView:
        let terminal = swiftTermView.getTerminal()
        return (0..<terminal.rows).compactMap { terminal.getLine(row: $0)?.translateToString(trimRight: true) }.joined(separator: "\n")
    default:
        return ""
    }
}

/// The tab's scrollback and screen.
@MainActor
private func allText(of tab: any TabTerminalView) -> String {
    switch tab {
    case let ghosttyView as GhosttyTabTerminalView:
        ghosttyView.selectAll(nil)
        return ghosttyView.terminalSurface?.readSelection() ?? ""
    case let swiftTermView as SelectableTerminalView:
        return String(decoding: swiftTermView.getTerminal().getBufferAsData(), as: UTF8.self)
    default:
        return ""
    }
}

@MainActor
private func gridColumns(of tab: any TabTerminalView) -> Int {
    switch tab {
    case let ghosttyView as GhosttyTabTerminalView: Int(ghosttyView.viewport?.columns ?? 0)
    case let swiftTermView as SelectableTerminalView: swiftTermView.getTerminal().cols
    default: 0
    }
}

@MainActor
private func waitUntil(timeout: Duration, _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { throw MeasurementTimeout() }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private struct MeasurementTimeout: Error {}

// MARK: - Workloads

/// Rewrites 8 rows 30 times a second, as `TerminalVisibilityMeasurements` does, with a spinner and the frame number
/// on the last row. Arguments: the file to wait for, then the number of frames.
private enum RepaintScript {
    static func write(to folder: URL) throws {
        try source.write(to: folder.appendingPathComponent("repaint.pl"), atomically: true, encoding: .utf8)
    }

    private static let source = #"""
        use strict;
        use Time::HiRes qw(time sleep);
        my ($go, $frames) = @ARGV;
        sleep 0.005 until -e $go;
        binmode STDOUT, ':encoding(UTF-8)';
        $| = 1;
        my @spinner = map { chr } (0x280B, 0x2819, 0x2839, 0x2838, 0x283C, 0x2834, 0x2826, 0x2827, 0x2807, 0x280F);
        print "\e[?25l\e[2J";
        my $start = time;
        for my $frame (0 .. $frames - 1) {
            my $out = '';
            for my $row (0 .. 7) {
                $out .= "\e[" . ($row + 1) . ";1H\e[2K\e[36mWorking $spinner[$frame % 10] \x{2014} task $row: waiting for generated output\x{2026}";
                $out .= " frame $frame" if $row == 7;
                $out .= "\e[0m";
            }
            print $out;
            my $wait = $start + ($frame + 1) / 30 - time;
            sleep $wait if $wait > 0;
        }
        """#
}

/// About 20 MB of numbered, colored log lines: every fifth in truecolor, every seventh with CJK, some warnings. The
/// tab's command waits for `go`, writes the file with `cat`, then touches a file of its own.
private struct BulkStream {
    static let lastLine = "BULK-DONE"
    private static let targetByteCount = 20_000_000

    let file: URL
    let lineCount: Int
    let byteCount: Int

    init() throws {
        file = FileManager.default.temporaryDirectory.appendingPathComponent("JustSessionsTests-bulk-\(UUID().uuidString).txt")
        var bytes: [UInt8] = []
        bytes.reserveCapacity(Self.targetByteCount + 4096)
        var line = 0
        while bytes.count < Self.targetByteCount {
            bytes.append(contentsOf: Self.line(line).utf8)
            line += 1
        }
        bytes.append(contentsOf: Self.lastLine.utf8)
        try Data(bytes).write(to: file)
        lineCount = line
        byteCount = bytes.count
    }

    var megabytes: String { String(format: "%.0f", Double(byteCount) / 1_000_000) }

    func command(touchingWhenWritten doneFile: String) -> String {
        "/usr/bin/perl -e 'select(undef, undef, undef, 0.005) until -e \"go\"'; /bin/cat '\(file.path)'; : > \(doneFile)"
    }

    func remove() {
        try? FileManager.default.removeItem(at: file)
    }

    /// The rows from the oldest numbered line the terminal kept to the last.
    func rowsKept(in text: String) -> Int {
        guard let match = text.firstMatch(of: #/L(\d{6}) /#), let first = Int(match.1) else { return 0 }
        return lineCount - first + 1
    }

    private static func line(_ index: Int) -> String {
        let number = String(format: "L%06d", index)
        let time = String(format: "\u{1B}[2m12:%02d:%02d.%03d\u{1B}[0m", index / 60_000 % 60, index / 1000 % 60, index % 1000)
        let level = index % 13 == 0 ? "\u{1B}[1;33mWARN\u{1B}[0m" : "\u{1B}[32mINFO\u{1B}[0m"
        let message: String
        if index % 5 == 0 {
            let red = index % 256, green = (index / 3) % 256, blue = 255 - index % 256
            message = "\u{1B}[38;2;\(red);\(green);\(blue)mrequest \(index) finished in \(index % 97) ms, cache warm\u{1B}[0m"
        } else if index % 7 == 0 {
            message = "处理请求 \(index) 完成：日本語のログ行、한국어 로그 줄"
        } else {
            message = "GET /api/v1/items/\(index % 1000)?page=\(index % 37) 200 \(index % 97).\(index % 10) ms bytes=\(index * 7 % 65536)"
        }
        return "\(number) \(time) \(level) [worker-\(index % 16)] \(message)\r\n"
    }
}

// MARK: - Meter

/// Process CPU, the main thread's CPU and longest gap, and frames drawn, from `start()` to `stop()`.
@MainActor
private final class EngineMeter {
    private let engine: TerminalEngine
    private let heartbeat = MainThreadPerfHeartbeat()
    private let ghosttyFrames = GhosttyFrameCounter()
    private var startTime = ContinuousClock.now
    private var processCPUAtStart = 0.0
    private var mainThreadCPUAtStart = 0.0

    init(engine: TerminalEngine) {
        self.engine = engine
    }

    func start(tabs: [any TabTerminalView]) {
        switch engine {
        case .ghostty: ghosttyFrames.start(observing: tabs.compactMap { $0 as? GhosttyTabTerminalView })
        case .swiftTerm: SwiftTermDrawCounter.install()
        }
        heartbeat.start()
        processCPUAtStart = processCPUSeconds()
        mainThreadCPUAtStart = mainThreadCPUSeconds()
        startTime = .now
    }

    func stop() -> EngineRun {
        let elapsed = ContinuousClock.now - startTime
        let processCPU = processCPUSeconds() - processCPUAtStart
        let mainThreadCPU = mainThreadCPUSeconds() - mainThreadCPUAtStart
        heartbeat.stop()
        let frames: Int
        switch engine {
        case .ghostty: frames = ghosttyFrames.stop()
        case .swiftTerm: frames = SwiftTermDrawCounter.uninstall()
        }
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let gap = heartbeat.longestGap
        return EngineRun(
            seconds: seconds,
            cpuPercent: processCPU / seconds * 100,
            mainThreadPercent: mainThreadCPU / seconds * 100,
            longestGapMilliseconds: Double(gap.components.seconds) * 1000 + Double(gap.components.attoseconds) / 1e15,
            framesDrawn: frames
        )
    }
}

/// Counts the frames Ghostty presents. Its renderer thread draws each frame into an IOSurface, which Ghostty's
/// layer, the view's backing layer, then takes on as its contents.
@MainActor
private final class GhosttyFrameCounter {
    private var observations: [NSKeyValueObservation] = []
    private let count = FrameCount()

    func start(observing views: [GhosttyTabTerminalView]) {
        observations = views.compactMap { view in
            view.layer?.observe(\.contents) { [count] _, _ in count.increment() }
        }
    }

    func stop() -> Int {
        observations.forEach { $0.invalidate() }
        observations = []
        return count.value
    }
}

private final class FrameCount: @unchecked Sendable {
    private let lock = NSLock()
    private var frames = 0

    func increment() { lock.withLock { frames += 1 } }
    var value: Int { lock.withLock { frames } }
}

/// Counts SwiftTerm's `draw(_:)` calls, one for each time a terminal view draws, while installed.
@MainActor
private enum SwiftTermDrawCounter {
    private typealias Draw = @convention(c) (NSView, Selector, NSRect) -> Void
    nonisolated(unsafe) private static var count = 0
    private static var originalDraw: IMP?

    static func install() {
        guard originalDraw == nil,
              let method = class_getInstanceMethod(SwiftTerm.TerminalView.self, #selector(NSView.draw(_:))) else { return }
        let original = method_getImplementation(method)
        let callOriginal = unsafeBitCast(original, to: Draw.self)
        let countingDraw: @convention(block) (NSView, NSRect) -> Void = { view, dirtyRect in
            count += 1
            callOriginal(view, #selector(NSView.draw(_:)), dirtyRect)
        }
        count = 0
        method_setImplementation(method, imp_implementationWithBlock(countingDraw))
        originalDraw = original
    }

    static func uninstall() -> Int {
        if let originalDraw, let method = class_getInstanceMethod(SwiftTerm.TerminalView.self, #selector(NSView.draw(_:))) {
            method_setImplementation(method, originalDraw)
        }
        originalDraw = nil
        return count
    }
}

private func processCPUSeconds() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
        + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
}

/// Called on the main thread, so the thread it reads is the main thread.
@MainActor
private func mainThreadCPUSeconds() -> Double {
    let thread = mach_thread_self()
    defer { mach_port_deallocate(mach_task_self_, thread) }
    var info = thread_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return 0 }
    return Double(info.user_time.seconds + info.system_time.seconds)
        + Double(info.user_time.microseconds + info.system_time.microseconds) / 1_000_000
}

/// The process's memory once its footprint has stopped changing for 2 seconds, after at least 3: a closed tab's
/// memory is let go a while after it closes, and a new tab's settles a while after it opens.
@MainActor
private func settledMemory() async throws -> MemoryUsage {
    try await Task.sleep(for: .seconds(3))
    var readings = [MemoryUsage.now()]
    let deadline = ContinuousClock.now + .seconds(30)
    while ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(250))
        readings.append(MemoryUsage.now())
        let recent = readings.suffix(9).map(\.footprint)
        if recent.count == 9, recent.max()! - recent.min()! < 256 << 10 { break }
    }
    return readings.last!
}

private struct MemoryUsage {
    /// What macOS charges the process, as Activity Monitor's Memory column shows it. Ghostty's terminal pages are
    /// resident but not counted here; see docs/development/performance.md.
    let footprint: UInt64
    /// The process's pages in RAM, which also counts Ghostty's terminal pages.
    let resident: UInt64

    /// Read once the allocator has given back the pages freed since the last reading.
    static func now() -> MemoryUsage {
        malloc_zone_pressure_relief(nil, 0)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return MemoryUsage(footprint: 0, resident: 0) }
        return MemoryUsage(footprint: info.phys_footprint, resident: info.resident_size)
    }
}
