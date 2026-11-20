import Testing

let conditionTimeoutForASlowFullRun: Duration = .seconds(120)

@MainActor
func expectEventually(
    timeout: Duration = conditionTimeoutForASlowFullRun,
    _ condition: () -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition(), clock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(condition(), sourceLocation: sourceLocation)
}
