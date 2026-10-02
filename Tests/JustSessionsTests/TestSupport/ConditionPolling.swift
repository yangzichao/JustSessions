import Testing

/// Checks `condition` every 10 ms until it holds or `timeout` passes, then expects it to hold. Sleeping instead of
/// blocking lets the store finish its background work on the main actor meanwhile. Shared CI runners can spend
/// several seconds rendering other AppKit suites; the deadline allows that contention without changing the assertion.
@MainActor
func expectEventually(
    timeout: Duration = .seconds(30),
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
