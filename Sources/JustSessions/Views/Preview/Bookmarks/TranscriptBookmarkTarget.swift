import AppKit
import SwiftUI

@MainActor
final class TranscriptBookmarkTarget {
    struct Shown: Equatable {
        let entryID: Int
        let frame: CGRect
        let topPadding: CGFloat
    }

    private(set) var shown: Shown?
    weak var marks: TranscriptBookmarkTargetMarksView? {
        didSet { marks?.show(shown) }
    }

    func show(_ shown: Shown?) {
        guard self.shown != shown else { return }
        self.shown = shown
        marks?.show(shown)
    }
}

struct TranscriptBookmarkTargetMarks: NSViewRepresentable {
    let target: TranscriptBookmarkTarget

    func makeNSView(context: Context) -> TranscriptBookmarkTargetMarksView {
        TranscriptBookmarkTargetMarksView()
    }

    func updateNSView(_ view: TranscriptBookmarkTargetMarksView, context: Context) {
        view.style = TranscriptBookmarkTargetMarkView.Style(
            color: NSColor(Color(ThemePalette.secondaryText.resolve(in: context.environment))),
            letters: context.environment.transcriptBookmarkLetters,
            side: TranscriptBookmarkMarker.side
        )
        if target.marks !== view { target.marks = view }
    }
}

/// Spans the gutter column the height of the entries and draws nothing itself, so it has no backing store to fill.
final class TranscriptBookmarkTargetMarksView: NSView {
    private let mark = TranscriptBookmarkTargetMarkView()
    private var shown: TranscriptBookmarkTarget.Shown?

    var style: TranscriptBookmarkTargetMarkView.Style? {
        didSet {
            guard style != oldValue else { return }
            show(shown)
        }
    }

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        mark.isHidden = true
        addSubview(mark)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { clickTarget(at: point, for: NSApp.currentEvent?.type) }

    func clickTarget(at point: NSPoint, for eventType: NSEvent.EventType?) -> NSView? {
        mark.isHidden ? nil : mark.clickTarget(at: convert(point, from: superview), for: eventType)
    }

    override func isAccessibilityElement() -> Bool { false }

    func show(_ shown: TranscriptBookmarkTarget.Shown?) {
        self.shown = shown
        guard let shown, let style else {
            mark.isHidden = true
            return
        }
        let slotX = TranscriptColumnLayout.gutterWidth - style.side - TranscriptBookmarkMarker.gapToText
        let top = shown.frame.minY + shown.topPadding
        let frame = CGRect(x: slotX, y: top, width: style.side, height: max(style.side, shown.frame.maxY - 4 - top))
        let content = TranscriptBookmarkTargetMarkView.Content(
            style: style, entryID: shown.entryID,
            letter: style.letters.letter(forEntryID: shown.entryID))
        if mark.frame != frame { mark.frame = frame }
        if mark.content != content {
            mark.content = content
            mark.needsDisplay = true
            mark.toolTip = content.hasLetter ? nil : AppLocalization.string("Add bookmark")
        }
        mark.isHidden = false
        window?.invalidateCursorRects(for: mark)
    }
}

final class TranscriptBookmarkTargetMarkView: NSView {
    struct Style: Equatable {
        let color: NSColor
        let letters: TranscriptBookmarkLetters
        let side: CGFloat
    }

    struct Content: Equatable {
        let style: Style
        let entryID: Int
        let letter: String?

        var hasLetter: Bool { letter != nil }
    }

    static let ringWidth: CGFloat = 1.5
    static let lineWidth: CGFloat = 2
    static let clickEvents: Set<NSEvent.EventType> = [
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp,
    ]
    var content: Content?
    private var isShowingMenu = false

    override var isFlipped: Bool { true }

    private var slot: CGRect {
        let side = content?.style.side ?? 0
        return CGRect(x: 0, y: 0, width: side, height: side)
    }

    private var isShown: Bool { content != nil && !isHidden }

    override func hitTest(_ point: NSPoint) -> NSView? { clickTarget(at: point, for: NSApp.currentEvent?.type) }

    func clickTarget(at point: NSPoint, for eventType: NSEvent.EventType?) -> NSView? {
        guard isShown, let eventType, Self.clickEvents.contains(eventType), slot.contains(convert(point, from: superview))
        else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        isShowingMenu = event.modifierFlags.contains(.control)
        if isShowingMenu, let menu = menu(for: event) { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }

    override func mouseUp(with event: NSEvent) {
        defer { isShowingMenu = false }
        guard !isShowingMenu, slot.contains(convert(event.locationInWindow, from: nil)) else { return }
        toggleBookmark()
    }

    override func resetCursorRects() {
        if isShown { addCursorRect(slot, cursor: .pointingHand) }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let content, let commands = TranscriptBookmarkTargetRegistry.shared.target(for: self) else { return nil }
        var items = commands.contextMenuItems(content.entryID)
        if !content.hasLetter, items.contains(where: { $0.action != nil }) {
            items.append(
                ActionMenuItem(title: AppLocalization.string("Edit bookmark…"), systemImage: "pencil") {
                    commands.editBookmarkOnEntry(content.entryID)
                })
        }
        guard !items.isEmpty else { return nil }
        let menu = NSMenu()
        items.forEach(menu.addItem)
        return menu
    }

    private func toggleBookmark() {
        guard let content else { return }
        TranscriptBookmarkTargetRegistry.shared.target(for: self)?.toggleBookmarkOnEntry(content.entryID)
    }

    override func isAccessibilityElement() -> Bool { isShown }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? {
        content?.letter.map { AppLocalization.string("Remove bookmark \($0)") } ?? AppLocalization.string("Add bookmark")
    }
    override func accessibilityPerformPress() -> Bool {
        guard isShown else { return false }
        toggleBookmark()
        return true
    }
    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        guard let content, isShown else { return nil }
        let name = content.letter.map { AppLocalization.string("Edit bookmark \($0)…") } ?? AppLocalization.string("Edit bookmark…")
        return [
            NSAccessibilityCustomAction(name: name) { [weak self] in
                guard let self else { return false }
                TranscriptBookmarkTargetRegistry.shared.target(for: self)?.editBookmarkOnEntry(content.entryID)
                return true
            }
        ]
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let content else { return }
        let side = content.style.side
        content.style.color.set()
        let slot = CGRect(x: 0, y: 0, width: side, height: side)
        let ring = NSBezierPath(
            roundedRect: slot.insetBy(dx: Self.ringWidth / 2, dy: Self.ringWidth / 2),
            xRadius: ThemeCornerRadius.small.rawValue, yRadius: ThemeCornerRadius.small.rawValue)
        ring.lineWidth = Self.ringWidth
        ring.stroke()
        if !content.hasLetter { Self.bookmarkOutline(in: slot.insetBy(dx: side * 0.3, dy: side * 0.22)).stroke() }
        let lineTop = side + 3
        if bounds.height - lineTop > 4 {
            NSBezierPath(
                roundedRect: CGRect(x: side / 2 - Self.lineWidth / 2, y: lineTop, width: Self.lineWidth, height: bounds.height - lineTop),
                xRadius: Self.lineWidth / 2, yRadius: Self.lineWidth / 2
            ).fill()
        }
    }

    static func bookmarkOutline(in rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.4))
        path.line(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.close()
        path.lineWidth = 1.2
        path.lineJoinStyle = .round
        return path
    }
}
