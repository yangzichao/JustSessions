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
            try await harness.resetViewport(to: .top)
            perfReport(label, "AppKit views in the window", harness.viewCount)
            perfReport(label, "most common AppKit views", harness.mostCommonViewClasses)
            for (name, value) in try await harness.measureScrolling() { perfReport(label, name, value) }
            for (name, value) in try await harness.measureHitTesting() { perfReport(label, name, value) }
            for (name, value) in try await harness.measureOpeningFind() { perfReport(label, name, value) }
            for (name, value) in try await harness.measurePositionLookup() { perfReport(label, name, value) }
        }
        #expect(entryCount > 0)  // Record-only: the numbers above are the result.
    }

    /// Reading as the app's readers do, with the bookmark commands on: a store and a paging model, so each scroll update
    /// finds the message being read and highlights it (RDR-48, PERF-73). The paging model loads nothing.
    @Test(arguments: [240, 640])
    func readingWithTheBookmarkCommandsOn(entryCount: Int) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let harness = try await TranscriptPerfHarness(entryCount: entryCount, bookmarkCommands: true)
        defer { harness.close() }
        for isAccessibilityOn in [false, true] {
            try await harness.setAccessibility(isAccessibilityOn)
            let label = "transcript N=\(entryCount), bookmark commands on, accessibility \(isAccessibilityOn ? "on" : "off")"
            try await harness.resetViewport(to: .top)
            perfReport(label, "AppKit views in the window", harness.viewCount)
            for (name, value) in try await harness.measureScrolling() { perfReport(label, name, value) }
            for (name, value) in try await harness.measureHitTesting() { perfReport(label, name, value) }
            for (name, value) in try await harness.measurePointerMoves() { perfReport(label, name, value) }
        }
        #expect(entryCount > 0)  // Record-only: the numbers above are the result.
    }

    /// The same reading with a letter beside 26 messages, so the markers' cost shows beside the plain reader's. Labelled,
    /// each letter takes the pointer for its hover card (RDR-51, PERF-73).
    @Test(arguments: [(240, false), (640, false), (240, true), (640, true)])
    func readingWithTwentySixBookmarks(entryCount: Int, labelled: Bool) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let harness = try await TranscriptPerfHarness(entryCount: entryCount, bookmarkCount: 26, labelled: labelled)
        defer { harness.close() }
        for isAccessibilityOn in [false, true] {
            try await harness.setAccessibility(isAccessibilityOn)
            let bookmarks = labelled ? "26 labelled bookmarks" : "26 bookmarks"
            let label = "transcript N=\(entryCount), \(bookmarks), accessibility \(isAccessibilityOn ? "on" : "off")"
            try await harness.resetViewport(to: .top)
            perfReport(label, "AppKit views in the window", harness.viewCount)
            for (name, value) in try await harness.measureScrolling() { perfReport(label, name, value) }
            for (name, value) in try await harness.measureHitTesting() { perfReport(label, name, value) }
        }
        #expect(entryCount > 0)  // Record-only: the numbers above are the result.
    }
}

@MainActor
final class TranscriptPerfHarness {
    private let window: NSWindow
    private let hostingView: NSHostingView<AnyView>
    private let settings: IsolatedUserDefaults
    private let searchState = TranscriptSearchState()
    private var earlierAccessibilityValue: NSNumber?

    /// With `bookmarkCount`, that many of the first messages are bookmarked, `labelled` with a label and two tags. The reader
    /// isn't paged, so the markers show and the bookmark commands stay off.
    /// With `bookmarkCommands`, the reader keeps bookmarks and has a paging model, as the app's readers do.
    init(entryCount: Int, bookmarkCount: Int = 0, labelled: Bool = false, bookmarkCommands: Bool = false) async throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        let conversation = TranscriptScrollViewFixture.conversation("transcript-perf-\(entryCount)")
        let transcript = Self.transcript(count: entryCount)
        var store: ConversationStore?
        if bookmarkCount > 0 {
            let messages = transcript.entries.compactMap { entry in MessageBookmark.Kind(entry.content).map { (entry, kind: $0) } }
            let bookmarks = zip(MessageBookmarks.letters, messages.prefix(bookmarkCount)).map { letter, message in
                MessageBookmark(
                    letter: letter, entryID: message.0.id, kind: message.kind,
                    snippet: MessageBookmarkNavigation.snippet(of: message.0) ?? "",
                    label: labelled ? "Label \(letter)" : nil, tags: labelled ? ["perf", "tag-\(letter)"] : [])
            }
            MessageBookmarks(bookmarksByConversationID: [conversation.id: bookmarks]).save(to: settings.userDefaults)
            store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        }
        if bookmarkCommands, store == nil {
            store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        }
        hostingView = NSHostingView(
            rootView: AnyView(
                TranscriptScrollView(
                    conversation: conversation, transcript: transcript,
                    positionStore: TranscriptReadingPositionStore(), searchState: searchState,
                    paging: bookmarkCommands ? TranscriptPagingModel() : nil, store: store
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

    enum ViewportPosition {
        case top
        case middle

        var fraction: CGFloat {
            switch self {
            case .top: 0
            case .middle: 0.5
            }
        }
    }

    func resetViewport(to position: ViewportPosition) async throws {
        let scrollView = try #require(transcriptScrollView)
        let clipView = scrollView.contentView
        let scrollableHeight = max(0, clipView.documentRect.height - clipView.bounds.height)
        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
        clipView.scroll(to: NSPoint(x: 0, y: scrollableHeight * position.fraction))
        scrollView.reflectScrolledClipView(clipView)
        try await pumpTurns(3)
    }

    /// The transcript from top to bottom in 60 steps. Each step is the scroll, the layout and drawing it forces, and
    /// then what the reader does in response on the next turn of the run loop, such as recording the reading position.
    func measureScrolling(steps: Int = 60) async throws -> [(String, String)] {
        try await resetViewport(to: .top)
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
            ("scroll: p95 step", perfMilliseconds(sorted[Int((Double(sorted.count) * 0.95).rounded(.up)) - 1])),
            ("scroll: worst step", perfMilliseconds(sorted.last ?? .zero)),
        ]
    }

    func measurePositionLookup(iterations: Int = 1_000) async throws -> [(String, String)] {
        try await resetViewport(to: .middle)
        guard let scrollView = transcriptScrollView,
            let lookup = PositionLookup(in: hostingView, scrollView: scrollView)
        else { return [] }
        var checksum = 0
        let total = ContinuousClock().measure {
            for _ in 0..<iterations { checksum &+= lookup.firstVisibleEntryIndex() ?? 0 }
        }
        return [("position lookup: \(iterations)", "\(perfMilliseconds(total)); checksum \(checksum)")]
    }

    /// What AppKit and SwiftUI do to find the view under the pointer, which they repeat for hover and cursor updates
    /// after every change to the window's content: 200 points spread over the transcript.
    func measureHitTesting() async throws -> [(String, String)] {
        try await resetViewport(to: .middle)
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

    /// The pointer moving down the reader with the bookmark commands on (RDR-48): 200 moves over the middle of the
    /// transcript, each handed to the reader as its tracking area hands it, which finds the row at the pointer's height and
    /// moves the mark when that message changes. Reports the time to handle them, then the mark's moves.
    func measurePointerMoves() async throws -> [(String, String)] {
        try await resetViewport(to: .middle)
        guard let controller = Self.descendant(ofType: TranscriptEntryGeometryView.self, in: hostingView)?.controller else { return [] }
        let bounds = hostingView.bounds
        let locations = (0..<200).map { index in
            hostingView.convert(NSPoint(x: bounds.midX, y: bounds.minY + bounds.height * CGFloat(index + 1) / 201), to: nil)
        }
        var handled = Duration.zero
        for location in locations {
            handled += turn { controller.pointerMoved(to: location) }
        }
        try await pumpTurns(2)
        controller.pointerLeft()
        try await pumpTurns(2)
        return [("pointer: 200 moves", perfMilliseconds(handled))]
    }

    private static func descendant<View: NSView>(ofType type: View.Type, in view: NSView) -> View? {
        if let view = view as? View { return view }
        for subview in view.subviews { if let found = descendant(ofType: type, in: subview) { return found } }
        return nil
    }

    /// Opening and closing Find without a query updates every text block, as any change to the search context does.
    func measureOpeningFind() async throws -> [(String, String)] {
        try await resetViewport(to: .middle)
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
        TranscriptContent(
            entries: (0..<count).map { index in
                let content: TranscriptEntry.Content =
                    switch index % 4 {
                    case 0: .userMessage("Question \(index): why does the sidebar redraw when a session in another project changes?")
                    case 1:
                        .assistantMessage(
                            """
                            The sidebar redraws because **every row** reads the store, entry \(index). Three changes help:

                            - Read only the `session` a row shows.
                            - Keep the project list *lazy*.
                            - Batch updates from the [poller](https://example.com).

                            ```swift
                            let rows = projects.flatMap(\\.sessions).filter { $0.isVisible }
                            print(rows.count)
                            ```
                            """)
                    case 2:
                        .toolCalls([
                            "Read Sources/JustSessions/Views/Browser/Sidebar/SidebarSessionRow.swift", "Bash swift build",
                            "Edit SidebarSessionRow.swift",
                        ])
                    default:
                        .assistantMessage(
                            String(
                                repeating: "This paragraph explains the change in detail, entry \(index), so it wraps over several lines. ",
                                count: 4))
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
            NSApp.perform(
                NSSelectorFromString("accessibilitySetValue:forAttribute:"), with: newValue ?? NSNumber(value: false),
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

@MainActor
private enum PositionLookup {
    struct Geometry {
        let entryIndex: Int
        let frame: CGRect
    }

    case markers([(entryIndex: Int, view: NSView)], clipView: NSClipView)
    case orderedGeometry([Geometry], geometryView: NSView, clipView: NSClipView)

    init?(in rootView: NSView, scrollView: NSScrollView) {
        let views = Self.descendants(in: rootView)
        let markers = views.filter { String(describing: type(of: $0)).hasSuffix("TranscriptEntryPositionMarkerView") }
            .compactMap { view -> (Int, NSView)? in
                guard let entryIndex = Self.child(named: "entryIndex", in: view) as? Int else { return nil }
                return (entryIndex, view)
            }
        if !markers.isEmpty {
            self = .markers(markers, clipView: scrollView.contentView)
            return
        }

        guard
            let geometryView = views.first(where: {
                String(describing: type(of: $0)).hasSuffix("TranscriptEntryGeometryView")
            }), let controller = Self.child(named: "controller", in: geometryView),
            let storedGeometries = Self.child(named: "entryGeometries", in: controller)
        else { return nil }
        let geometries = Mirror(reflecting: storedGeometries).children.compactMap { child -> Geometry? in
            guard let entryIndex = Self.child(named: "entryIndex", in: child.value) as? Int,
                let frame = Self.child(named: "frame", in: child.value) as? CGRect
            else { return nil }
            return Geometry(entryIndex: entryIndex, frame: frame)
        }
        guard !geometries.isEmpty else { return nil }
        self = .orderedGeometry(geometries, geometryView: geometryView, clipView: scrollView.contentView)
    }

    func firstVisibleEntryIndex() -> Int? {
        switch self {
        case .markers(let markers, let clipView):
            let visibleBounds = clipView.bounds
            return markers.compactMap { marker -> (Int, CGRect)? in
                let frame = marker.view.convert(marker.view.bounds, to: clipView)
                guard frame.maxY > visibleBounds.minY, frame.minY < visibleBounds.maxY else { return nil }
                return (marker.entryIndex, frame)
            }.min(by: { $0.1.minY < $1.1.minY })?.0
        case .orderedGeometry(let geometries, let geometryView, let clipView):
            let visibleBounds = geometryView.convert(clipView.bounds, from: clipView)
            var lowerBound = 0
            var upperBound = geometries.count
            while lowerBound < upperBound {
                let middle = lowerBound + (upperBound - lowerBound) / 2
                if geometries[middle].frame.maxY <= visibleBounds.minY {
                    lowerBound = middle + 1
                } else {
                    upperBound = middle
                }
            }
            guard lowerBound < geometries.count, geometries[lowerBound].frame.minY < visibleBounds.maxY else { return nil }
            return geometries[lowerBound].entryIndex
        }
    }

    private static func child(named name: String, in value: Any) -> Any? {
        let unwrapped = unwrap(value)
        var mirror: Mirror? = Mirror(reflecting: unwrapped)
        while let current = mirror {
            if let child = current.children.first(where: { $0.label == name }) { return unwrap(child.value) }
            mirror = current.superclassMirror
        }
        return nil
    }

    private static func unwrap(_ value: Any) -> Any {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional, let wrapped = mirror.children.first?.value { return unwrap(wrapped) }
        return value
    }

    private static func descendants(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }
}
