import SwiftUI

struct HostDisconnectConfirmation: ViewModifier {
    let store: ConversationStore

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: presentation(ofKeepOrEnd: true), presenting: store.hostDisconnectQuestion) { question in
                Button("Keep running") { store.disconnectHost(question.host, endingTmuxSessions: false) }
                    .keyboardShortcut(.defaultAction)
                Button("End sessions", role: .destructive) { store.disconnectHost(question.host, endingTmuxSessions: true) }
                Button("Cancel", role: .cancel) { store.hostDisconnectQuestion = nil }
            } message: { question in
                if case .keepOrEndCLIs(alsoStopsOthers: true) = question.question {
                    Text(
                        "Its open tabs close. Keep running leaves their CLIs running in tmux; click a session to reattach once you connect again. End sessions stops them. The other tabs' CLIs and shells stop either way."
                    )
                } else {
                    Text(
                        "Its open tabs close. Keep running leaves their CLIs running in tmux; click a session to reattach once you connect again. End sessions stops them."
                    )
                }
            }
            .alert(title, isPresented: presentation(ofKeepOrEnd: false), presenting: store.hostDisconnectQuestion) { question in
                Button("Close tabs", role: .destructive) { store.disconnectHost(question.host, endingTmuxSessions: true) }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { store.hostDisconnectQuestion = nil }
            } message: { _ in
                Text("Its open tabs close, and the CLIs and shells running in them stop.")
            }
            .dismissesOnClickOutside(item: question)
    }

    private var title: Text {
        Text("Disconnect from \(store.hostDisconnectQuestion?.host ?? "")?")
    }

    private var question: Binding<HostDisconnectQuestion?> {
        Binding(get: { store.hostDisconnectQuestion }, set: { store.hostDisconnectQuestion = $0 })
    }

    private func presentation(ofKeepOrEnd showsKeepOrEnd: Bool) -> Binding<Bool> {
        Binding(
            get: {
                switch store.hostDisconnectQuestion?.question {
                case .keepOrEndCLIs: showsKeepOrEnd
                case .stopEverything: !showsKeepOrEnd
                case .closeWithoutAsking, nil: false
                }
            },
            set: { isPresented in if !isPresented { store.hostDisconnectQuestion = nil } }
        )
    }
}
