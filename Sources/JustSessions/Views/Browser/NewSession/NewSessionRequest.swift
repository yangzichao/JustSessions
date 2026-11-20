struct NewSessionRequest {
    let launch: NewSessionLaunch
    let host: SessionHost
    let folder: String
    let creatingMissingFolder: Bool
}
