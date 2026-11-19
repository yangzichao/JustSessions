struct NewSessionRequest {
    let kind: NewSessionKind
    let host: SessionHost
    let folder: String
    let creatingMissingFolder: Bool
    let deletesSessionWhenClosed: Bool
}
