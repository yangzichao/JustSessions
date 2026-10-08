/// What the New session sheet asks to start: a tool or a terminal, on a host, in the folder typed there.
struct NewSessionRequest {
    let kind: NewSessionKind
    let host: SessionHost
    let folder: String
}
