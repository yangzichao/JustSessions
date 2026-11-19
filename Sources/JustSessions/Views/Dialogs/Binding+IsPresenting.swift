import SwiftUI

extension Binding where Value == Bool {
    init<Wrapped: Sendable>(isPresenting optionalValue: Binding<Wrapped?>) {
        self.init(
            get: { optionalValue.wrappedValue != nil },
            set: { isPresented in
                if !isPresented { optionalValue.wrappedValue = nil }
            }
        )
    }
}
