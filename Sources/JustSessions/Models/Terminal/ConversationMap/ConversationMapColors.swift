struct ConversationMapColors: Equatable {
    let background, hairline, user, reply, tool, hoverBand, chip, chipText, caption: UInt32

    init(palette: TerminalPalette, provider: ConversationProvider) {
        typealias Contrast = ThemeColorContrast
        let background = palette.background
        let foreground = palette.scheme.foreground
        self.background = background
        hairline = Contrast.distinguishableFill(
            Contrast.blend(background, with: foreground, fraction: 0.15), on: background, minimumRatio: 1.3)
        user = Contrast.distinguishableFill(Contrast.blend(foreground, with: background, fraction: 0.25), on: background, minimumRatio: 3)
        reply = Contrast.distinguishableFill(provider.tintHexColor.value(isDark: palette.isDark), on: background, minimumRatio: 3)
        tool = Contrast.distinguishableFill(Contrast.blend(foreground, with: background, fraction: 0.7), on: background, minimumRatio: 1.6)
        hoverBand = Contrast.blend(background, with: foreground, fraction: 0.1)
        chip = Contrast.distinguishableFill(foreground, on: background, minimumRatio: 3)
        chipText = Contrast.readableText(background, on: [chip])
        caption = Contrast.readableText(Contrast.blend(foreground, with: background, fraction: 0.35), on: [background])
    }

    func hex(for ink: ConversationMapLayout.Ink) -> UInt32 {
        switch ink {
        case .user: user
        case .assistant: reply
        case .toolRun: tool
        }
    }
}
