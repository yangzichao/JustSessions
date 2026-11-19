import SwiftUI

extension View {
    func appLanguage(from languageStore: AppLanguageStore) -> some View {
        modifier(ChosenAppLanguage(languageStore: languageStore))
    }
}

private struct ChosenAppLanguage: ViewModifier {
    @ObservedObject var languageStore: AppLanguageStore

    func body(content: Content) -> some View {
        content.environment(\.locale, languageStore.locale)
    }
}
