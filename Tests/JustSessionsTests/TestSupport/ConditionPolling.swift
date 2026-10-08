import Testing

/// Checks `condition` every 10 ms until it holds or `timeout` passes, then expects it to hold. Sleeping instead of
/// blocking lets the store finish its background work on the main actor meanwhile. At the start of a full run on the
/// release workflow's shared runner, when every suite starts at once, the main thread can stay busy for over 30
/// seconds: three v1.0.10 release runs each failed different tests whose waits ran out there. A passing condition
/// still returns at once, so the long default costs only a failing test's time.
@MainActor
func expectEventually(
    timeout: Duration = .seconds(120),
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
