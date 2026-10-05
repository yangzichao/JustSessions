/// What the New session sheet asks to start: a tool or a terminal, on a host, in the folder typed there.
struct NewSessionRequest {
    let kind: NewSessionKind
    let host: SessionHost
    let folder: String
    /// What the start command field holds for the tool; nil for a terminal, which has none.
    let startCommand: String?
}
