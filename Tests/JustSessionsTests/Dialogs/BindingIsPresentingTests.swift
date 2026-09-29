import SwiftUI
import Testing
@testable import JustSessions

/// Alerts and dialogs show while their value is set, and closing one clears the value.
struct BindingIsPresentingTests {
    @Test func presentsWhileTheValueIsSetAndClearsItWhenDismissed() {
        let storage = BindingStorage<String?>("draft")
        let isPresented = Binding(isPresenting: storage.binding)
        #expect(isPresented.wrappedValue)

        isPresented.wrappedValue = false
        #expect(storage.value == nil)
        #expect(!isPresented.wrappedValue)
    }

    @Test func presentingNeverInventsAValue() {
        let storage = BindingStorage<String?>(nil)
        let isPresented = Binding(isPresenting: storage.binding)
        #expect(!isPresented.wrappedValue)

        isPresented.wrappedValue = true
        #expect(storage.value == nil)
    }
}

/// Backs a test binding. Each test reads and writes its own storage from one task.
private final class BindingStorage<Value: Sendable>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }

    var binding: Binding<Value> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}
