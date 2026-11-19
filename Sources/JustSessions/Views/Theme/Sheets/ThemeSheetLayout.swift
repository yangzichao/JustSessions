import SwiftUI

struct ThemeSheetLayout<TitleAccessory: View, Content: View, Footer: View>: View {
    let title: Text
    var intro: Text?
    let width: CGFloat
    @ViewBuilder let titleAccessory: () -> TitleAccessory
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeSheetMetrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: ThemeSheetMetrics.titleToIntroSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    title.font(ThemeFont.title)
                    titleAccessory()
                }
                if let intro {
                    intro
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
            HStack(spacing: 8) {
                footer()
            }
        }
        .buttonStyle(QuietBorderedButtonStyle())
        .padding(ThemeSheetMetrics.margin)
        .frame(width: width)
        .background(ThemePalette.contentSurface)
    }
}

extension ThemeSheetLayout where TitleAccessory == EmptyView {
    init(
        title: Text,
        intro: Text? = nil,
        width: CGFloat,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(title: title, intro: intro, width: width, titleAccessory: { EmptyView() }, content: content, footer: footer)
    }
}
