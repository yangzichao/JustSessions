import Foundation

final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        storedValue = value
    }

    var value: Value { lock.withLock { storedValue } }

    func update(_ change: (inout Value) -> Void) {
        lock.withLock { change(&storedValue) }
    }
}
