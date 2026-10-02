import SwiftUI

/// Shows the store's alert: its title and message, OK, and Try Again when the alert offers it. Each button, and
/// the alert's own closing, dismisses only the alert it belongs to, so a newer one set meanwhile still shows.
private struct StoreAlertPresenter: ViewModifier {
    @ObservedObject var store: ConversationStore

    func body(content: Content) -> some View {
        let shownAlert = store.alert
        content.alert(Text(shownAlert?.title ?? StoreAlert.defaultTitle), isPresented: Binding(
            get: { store.alert != nil },
            set: { isPresented in
                if !isPresented, let shownAlert { store.dismissAlert(shownAlert) }
            }
        ), presenting: shownAlert) { alert in
            // Return keeps OK: Try Again deletes, permanently on SSH hosts, so it is never the default.
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
    }
}

extension View {
    func storeAlert(_ store: ConversationStore) -> some View {
        modifier(StoreAlertPresenter(store: store))
    }
}
