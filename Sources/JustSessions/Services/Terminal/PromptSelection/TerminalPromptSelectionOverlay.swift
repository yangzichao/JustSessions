import AppKit

final class TerminalPromptSelectionOverlay: NSView {
    struct Glyph {
        let character: Character
        let frame: NSRect
    }

    private var lineFrames: [NSRect] = []
    private var glyphs: [Glyph] = []
    private var style: PromptSelectionTextStyle?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func show(lineFrames: [NSRect], glyphs: [Glyph], style: PromptSelectionTextStyle) {
        self.lineFrames = lineFrames
        self.glyphs = glyphs
        self.style = style
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let style else { return }
        style.backgroundColor.setFill()
        for lineFrame in lineFrames { lineFrame.fill() }
        let attributes: [NSAttributedString.Key: Any] = [.font: style.font, .foregroundColor: style.foregroundColor]
        for glyph in glyphs {
            NSAttributedString(string: String(glyph.character), attributes: attributes).draw(at: glyph.frame.origin)
        }
    }
}
