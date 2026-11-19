import AppKit

/// One block of transcript text. AppKit draws it so a selection can run across blocks (see
/// `TranscriptTextSelectionCoordinator`), and so Find gets the actual location of a match, even deep inside a tall
/// message.
final class TranscriptTextView: NSTextView {
    /// Code is laid out at this width, so its lines never wrap; it scrolls sideways instead.
    static let unboundedWidth: CGFloat = 100_000

    var revealSelectedRange: ((NSTextView, NSRange) -> Bool)?
    var selectedSearchRange: NSRange?
    var navigationRevision = 0
    private var revealedRevision: Int?
    private var scheduledRevision: Int?
    private var revealAttempts = 0

    private(set) weak var selectionCoordinator: TranscriptTextSelectionCoordinator?
    private(set) var selectionKey: TranscriptTextSelectionKey?
    private(set) var copyRole: TranscriptTextCopyRole = .paragraph
    private var content: TranscriptTextContent?
    /// The text system's root object: AppKit leaves keeping it to whoever assembled the text system.
    private var assembledTextStorage: NSTextStorage?
    private var measuredSizes: [CGFloat: CGSize] = [:]
    /// The width of the text laid out at the text container's current width.
    private var laidOutTextWidth: CGFloat?

    init() {
        // TextKit 1, assembled here: a text view that falls back to it from TextKit 2 sets the text system up twice.
        let textStorage = NSTextStorage()
        let layoutManager = TranscriptTextLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: Self.unboundedWidth, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        assembledTextStorage = textStorage
        super.init(frame: .zero, textContainer: textContainer)
        isEditable = false
        isSelectable = true
        drawsBackground = false
        textContainerInset = .zero
        isVerticallyResizable = false
        isHorizontallyResizable = false
        focusRingType = .none
        selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
        setAccessibilityElement(true)
    }

    /// AppKit's `init(frame:)` sets up the text system through this initializer, called on the subclass, so it must be
    /// overridden for a text view made that way to return.
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    required init?(coder: NSCoder) { nil }

    var textLength: Int { textStorage?.length ?? 0 }

    // MARK: Content

    func setContent(_ newContent: TranscriptTextContent) {
        guard newContent != content else { return }
        let changesLayout = newContent.source != content?.source || newContent.style != content?.style
        content = newContent
        if changesLayout, let layoutManager = layoutManager as? TranscriptTextLayoutManager {
            layoutManager.lineHeightPadding = layoutManager.lineHeightPadding(for: newContent.style.font)
        }
        textStorage?.setAttributedString(newContent.attributedString())
        linkTextAttributes = [.foregroundColor: newContent.colors.link, .cursor: NSCursor.pointingHand]
        if changesLayout {
            measuredSizes = [:]
            laidOutTextWidth = nil
            invalidateIntrinsicContentSize()
        }
        // Replacing the text resets the selected range.
        selectionCoordinator?.applySelection(to: self)
    }

    func setSelection(coordinator: TranscriptTextSelectionCoordinator?, key: TranscriptTextSelectionKey, copyRole: TranscriptTextCopyRole) {
        self.copyRole = copyRole
        guard coordinator !== selectionCoordinator || key != selectionKey else { return }
        if window != nil { selectionCoordinator?.unregister(self) }
        selectionCoordinator = coordinator
        selectionKey = key
        if window != nil { coordinator?.register(self) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { selectionCoordinator?.register(self) } else { selectionCoordinator?.unregister(self) }
    }

    // MARK: Layout

    /// The size of the text laid out at `width`, or on one line per paragraph without one, as code is. Like SwiftUI's
    /// text, it is only as wide as its longest line, so a table column fits its widest cell.
    func measuredSize(width: CGFloat?) -> CGSize {
        let containerWidth = width.flatMap { $0.isFinite ? max(1, $0) : nil } ?? Self.unboundedWidth
        if let size = measuredSizes[containerWidth] { return size }
        guard let textContainer, let layoutManager else { return .zero }
        let usedSize = layOut(atWidth: containerWidth, textContainer: textContainer, layoutManager: layoutManager)
        // Rounded up to whole pixels, as SwiftUI's text was, so a placed view never wraps its last word.
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let size = CGSize(width: min(ceil(usedSize.width * scale) / scale, containerWidth), height: ceil(usedSize.height * scale) / scale)
        measuredSizes[containerWidth] = size
        return size
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        measuredSizes = [:]
    }

    /// SwiftUI may measure at several widths before it places the view, so the text is laid out again at the width it
    /// is placed at, unless the lines already laid out fit it and wrap the same.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard newSize.width > 0, let textContainer, let layoutManager else { return }
        let containerWidth = textContainer.size.width
        if containerWidth == newSize.width { return }
        if let laidOutTextWidth, laidOutTextWidth <= newSize.width, newSize.width <= containerWidth { return }
        _ = layOut(atWidth: newSize.width, textContainer: textContainer, layoutManager: layoutManager)
    }

    private func layOut(atWidth width: CGFloat, textContainer: NSTextContainer, layoutManager: NSLayoutManager) -> CGSize {
        if textContainer.size.width != width {
            textContainer.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        }
        layoutManager.ensureLayout(for: textContainer)
        var usedSize = layoutManager.usedRect(for: textContainer).size
        // The container's used rect spans a finite container's whole width; the longest line is the text's width.
        usedSize.width = 0
        layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(for: textContainer)) { _, lineUsedRect, _, _, _ in
            usedSize.width = max(usedSize.width, lineUsedRect.maxX)
        }
        // The empty line after a final line break skips the layout manager's delegate, which pads every other line.
        if layoutManager.extraLineFragmentTextContainer != nil, let layoutManager = layoutManager as? TranscriptTextLayoutManager {
            usedSize.height += layoutManager.lineHeightPadding
        }
        laidOutTextWidth = usedSize.width
        return usedSize
    }

    override func layout() {
        super.layout()
        scheduleReveal()
    }

    // MARK: Find

    private func scheduleReveal() {
        guard selectedSearchRange != nil, bounds.height > 0,
            revealedRevision != navigationRevision, scheduledRevision != navigationRevision
        else { return }
        let revision = navigationRevision
        revealAttempts = 0
        scheduledRevision = revision
        DispatchQueue.main.async { [weak self] in self?.reveal(revision: revision) }
    }

    private func reveal(revision: Int) {
        guard revision == navigationRevision, let range = selectedSearchRange else { return }
        if revealSelectedRange?(self, range) == true {
            revealedRevision = revision
        } else if revealAttempts < 30, window != nil {
            revealAttempts += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in self?.reveal(revision: revision) }
        }
    }
}
