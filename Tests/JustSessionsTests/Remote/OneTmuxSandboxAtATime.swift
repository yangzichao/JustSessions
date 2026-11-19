import Testing

struct OneTmuxSandboxAtATime: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        try await Self.turn.run(function)
    }

    private static let turn = TestTurn()
}

extension SuiteTrait where Self == OneTmuxSandboxAtATime {
    static var oneTmuxSandboxAtATime: Self { Self() }
}
