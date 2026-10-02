import SwiftUI

extension View {
    /// Update text in place: changing a language must preserve terminals, selection, and reading positions.
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
