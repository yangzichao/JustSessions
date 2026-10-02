import AppKit

/// Native text layout gives Find the actual location of an occurrence, even deep inside a tall message.
final class TranscriptSearchTextView: NSTextView {
    var revealSelectedRange: ((NSTextView, NSRange) -> Bool)?
    var selectedSearchRange: NSRange?
    var navigationRevision = 0
    private var revealedRevision: Int?
    private var scheduledRevision: Int?
    private var revealAttempts = 0

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = true
        drawsBackground = false
        textContainerInset = .zero
        textContainer?.lineFragmentPadding = 0
        textContainer?.widthTracksTextView = false
        textContainer?.heightTracksTextView = false
        isVerticallyResizable = false
        isHorizontallyResizable = false
        focusRingType = .none
        setAccessibilityElement(true)
    }

    required init?(coder: NSCoder) { nil }

    func measuredSize(width: CGFloat?) -> CGSize {
        guard let textContainer, let layoutManager else { return .zero }
        textContainer.containerSize = CGSize(width: max(1, width ?? 100_000), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedSize = layoutManager.usedRect(for: textContainer).size
        return CGSize(width: width ?? ceil(usedSize.width), height: ceil(usedSize.height))
    }

    override func layout() {
        super.layout()
        scheduleReveal()
    }

    private func scheduleReveal() {
        guard selectedSearchRange != nil, bounds.height > 0,
              revealedRevision != navigationRevision, scheduledRevision != navigationRevision else { return }
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
