actor TestTurn {
    private var isTaken = false
    private var waitingTests: [CheckedContinuation<Void, Never>] = []

    nonisolated func run(_ test: @Sendable () async throws -> Void) async throws {
        await take()
        do {
            try await test()
        } catch {
            await handOn()
            throw error
        }
        await handOn()
    }

    private func take() async {
        guard isTaken else {
            isTaken = true
            return
        }
        await withCheckedContinuation { continuation in
            waitingTests.append(continuation)
        }
    }

    private func handOn() {
        if waitingTests.isEmpty {
            isTaken = false
        } else {
            waitingTests.removeFirst().resume()
        }
    }
}
