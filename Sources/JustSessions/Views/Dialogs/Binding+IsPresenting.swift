import SwiftUI

extension Binding where Value == Bool {
    /// Presents an alert or dialog while `optionalValue` holds a value. Dismissing it clears `optionalValue`.
    init<Wrapped: Sendable>(isPresenting optionalValue: Binding<Wrapped?>) {
        self.init(
            get: { optionalValue.wrappedValue != nil },
            set: { isPresented in
                if !isPresented { optionalValue.wrappedValue = nil }
            }
        )
    }
}
