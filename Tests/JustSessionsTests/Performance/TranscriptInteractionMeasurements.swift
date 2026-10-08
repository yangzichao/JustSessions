import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// Measures reading a long transcript with the real reader hosted in a visible 1000×800 window, as
/// `Perf | <scenario> | <metric> | <value>` lines. Each measurement runs with SwiftUI's accessibility off, then on, as it
/// is while an assistive app is connected: VoiceOver, or apps such as Raycast and window managers. SwiftUI then also keeps
/// an accessibility tree and walks its views to track the accessibility focus; see docs/development/performance.md.
///
/// The suite records nothing unless `JUSTSESSIONS_PERF` is set:
///     JUSTSESSIONS_PERF=1 swift test -c release --filter TranscriptInteractionMeasurements
@MainActor
@Suite(.serialized)
struct TranscriptInteractionMeasurements {
    /// 80 entries make a page, and the reader keeps up to `TranscriptPagingModel.maximumRetainedPageCount` pages.
    @Test(arguments: [240, 640])
    func reading(entryCount: Int) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let harness = try await TranscriptPerfHarness(entryCount: entryCount)
        defer { harness.close() }
        for isAccessibilityOn in [false, true] {
            try await harness.setAccessibility(isAccessibilityOn)
            let label = "transcript N=\(entryCount), accessibility \(isAccessibilityOn ? "on" : "off")"
            perfReport(label, "AppKit views in the window", harness.viewCount)
            perfReport(label, "most common AppKit views", harness.mostCommonViewClasses)
            for (name, value) in try await harness.measureScrolling() { perfReport(label, name, value) }
            for (name, value) in harness.measureHitTesting() { perfReport(label, name, value) }
            for (name, value) in try await harness.measureOpeningFind() { perfReport(label, name, value) }
        }
        #expect(entryCount > 0) // Record-only: the numbers above are the result.
    }
}

@MainActor
final class TranscriptPerfHarness {
    private let window: NSWindow
    private let hostingView: NSHostingView<AnyView>
    private let settings: IsolatedUserDefaults
    private let searchState = TranscriptSearchState()
    private var earlierAccessibilityValue: NSNumber?

    init(entryCount: Int) async throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        let conversation = TranscriptScrollViewFixture.conversation("transcript-perf-\(entryCount)")
        hostingView = NSHostingView(rootView: AnyView(
            TranscriptScrollView(
                conversation: conversation, transcript: Self.transcript(count: entryCount),
                positionStore: TranscriptReadingPositionStore(), searchState: searchState
            )
            .defaultAppStorage(settings.userDefaults)
        ))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        window.orderFrontRegardless()
        earlierAccessibilityValue = Self.enhancedUserInterface
        try await settle()
    }

    func close() {
        Self.enhancedUserInterface = earlierAccessibilityValue ?? NSNumber(value: false)
        hostingView.rootView = AnyView(EmptyView())
        window.close()
        settings.removeSuite()
    }

    /// What an assistive app turns on, as `TranscriptScrollViewFixture.pressButton(labeled:)` describes.
    func setAccessibility(_ isOn: Bool) async throws {
        Self.enhancedUserInterface = NSNumber(value: isOn)
        if isOn { _ = hostingView.accessibilityChildren() }
        try await settle()
    }

    var viewCount: Int { Self.descendantCount(of: hostingView) }

    var mostCommonViewClasses: String {
        let counts = Dictionary(grouping: Self.descendants(ofType: NSView.self, in: hostingView)) { String(describing: type(of: $0)) }
            .mapValues(\.count)
        return counts.sorted { $0.value > $1.value }.prefix(8).map { "\($0.key) \($0.value)" }.joined(separator: ", ")
    }

    /// The transcript from top to bottom in 60 steps. Each step is the scroll, the layout and drawing it forces, and
    /// then what the reader does in response on the next turn of the run loop, such as recording the reading position.
    func measureScrolling(steps: Int = 60) async throws -> [(String, String)] {
        let scrollView = try #require(transcriptScrollView)
        let clipView = scrollView.contentView
        let scrollableHeight = max(0, clipView.documentRect.height - clipView.bounds.height)
        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
        var stepTimes: [Duration] = []
        for step in 0..<steps {
            let offset = scrollableHeight * CGFloat(step) / CGFloat(steps - 1)
            var stepTime = turn {
                clipView.scroll(to: NSPoint(x: 0, y: offset))
                scrollView.reflectScrolledClipView(clipView)
            }
            try await Task.sleep(for: .milliseconds(1))
            stepTime += turn {}
            stepTimes.append(stepTime)
        }
        let sorted = stepTimes.sorted()
        return [
            ("document height", String(format: "%.0f pt", clipView.documentRect.height)),
            ("scroll: total of \(steps) steps", perfMilliseconds(stepTimes.reduce(.zero, +))),
            ("scroll: median step", perfMilliseconds(sorted[sorted.count / 2])),
            ("scroll: worst step", perfMilliseconds(sorted.last ?? .zero)),
        ]
    }

    /// What AppKit and SwiftUI do to find the view under the pointer, which they repeat for hover and cursor updates
    /// after every change to the window's content: 200 points spread over the transcript.
    func measureHitTesting() -> [(String, String)] {
        let bounds = hostingView.bounds
        let points = (0..<200).map { index -> NSPoint in
            let column = CGFloat(index % 20 + 1) / 21
            let row = CGFloat(index / 20 + 1) / 11
            return NSPoint(x: bounds.minX + bounds.width * column, y: bounds.minY + bounds.height * row)
        }
        let superview = hostingView.superview
        let total = ContinuousClock().measure {
            for point in points {
                _ = hostingView.hitTest(superview.map { hostingView.convert(point, to: $0) } ?? point)
            }
        }
        return [("hit test: 200 points", perfMilliseconds(total))]
    }

    /// Opening and closing Find without a query updates every text block, as any change to the search context does.
    func measureOpeningFind() async throws -> [(String, String)] {
        let opening = turn { searchState.show() }
        try await pumpTurns(2)
        let closing = turn { searchState.close() }
        try await pumpTurns(2)
        return [
            ("open Find: turn", perfMilliseconds(opening)),
            ("close Find: turn", perfMilliseconds(closing)),
        ]
    }

    private var transcriptScrollView: NSScrollView? {
        Self.descendants(ofType: NSScrollView.self, in: hostingView)
            .max { ($0.documentView?.bounds.height ?? 0) < ($1.documentView?.bounds.height ?? 0) }
    }

    private func turn(_ change: () -> Void) -> Duration {
        ContinuousClock().measure {
            change()
            hostingView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }
    }

    private func pumpTurns(_ count: Int) async throws {
        for _ in 0..<count {
            hostingView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    func settle() async throws {
        for _ in 0..<12 {
            hostingView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    /// Reading entries as a session has them: prompts, replies with prose, lists, and code, and runs of tool calls.
    static func transcript(count: Int) -> TranscriptContent {
        TranscriptContent(entries: (0..<count).map { index in
            let content: TranscriptEntry.Content = switch index % 4 {
            case 0: .userMessage("Question \(index): why does the sidebar redraw when a session in another project changes?")
            case 1: .assistantMessage("""
                The sidebar redraws because **every row** reads the store, entry \(index). Three changes help:

                - Read only the `session` a row shows.
                - Keep the project list *lazy*.
                - Batch updates from the [poller](https://example.com).

                ```swift
                let rows = projects.flatMap(\\.sessions).filter { $0.isVisible }
                print(rows.count)
                ```
                """)
            case 2: .toolCalls(["Read Sources/JustSessions/Views/Browser/Sidebar/SidebarSessionRow.swift", "Bash swift build", "Edit SidebarSessionRow.swift"])
            default: .assistantMessage(String(repeating: "This paragraph explains the change in detail, entry \(index), so it wraps over several lines. ", count: 4))
            }
            var entry = TranscriptEntry(id: index, content: content, timestamp: nil, startsTurn: index % 4 == 0)
            if case .assistantMessage(let text) = content { entry.markdown = PreparedTranscriptMarkdown(text: text) }
            return entry
        }, omittedEntryCount: 0)
    }

    /// The app-wide setting an assistive app turns on. The attribute accessors exist only in the deprecated informal
    /// accessibility API, so they are called by selector.
    private static var enhancedUserInterface: NSNumber? {
        get {
            NSApp.perform(NSSelectorFromString("accessibilityAttributeValue:"), with: "AXEnhancedUserInterface" as NSString)?
                .takeUnretainedValue() as? NSNumber
        }
        set {
            NSApp.perform(NSSelectorFromString("accessibilitySetValue:forAttribute:"), with: newValue ?? NSNumber(value: false),
                          with: "AXEnhancedUserInterface" as NSString)
        }
    }

    private static func descendantCount(of view: NSView) -> Int {
        view.subviews.reduce(view.subviews.count) { $0 + descendantCount(of: $1) }
    }

    private static func descendants<ViewType: NSView>(ofType type: ViewType.Type, in view: NSView) -> [ViewType] {
        ((view as? ViewType).map { [$0] } ?? []) + view.subviews.flatMap { descendants(ofType: type, in: $0) }
    }
}
