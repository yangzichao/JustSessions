import SwiftUI

private struct StoreAlertPresenter: ViewModifier {
    let store: ConversationStore

    func body(content: Content) -> some View {
        let shownAlert = store.alert
        let isPresented = Binding(
            get: { store.alert != nil },
            set: { isPresented in
                if !isPresented, let shownAlert { store.dismissAlert(shownAlert) }
            }
        )
        content.alert(Text(shownAlert?.title ?? StoreAlert.defaultTitle), isPresented: isPresented, presenting: shownAlert) { alert in
            Button("OK") { store.dismissAlert(alert) }
                .keyboardShortcut(.defaultAction)
            if alert.offersTryAgain {
                Button("Try Again") {
                    store.dismissAlert(alert)
                    store.retryDeletion(of: alert.retryConversationIDs)
                }
            }
        } message: { alert in
            Text(alert.message)
        }
        .dismissesOnClickOutside(isPresented: isPresented)
    }
}

extension View {
    func storeAlert(_ store: ConversationStore) -> some View {
        modifier(StoreAlertPresenter(store: store))
    }
}
