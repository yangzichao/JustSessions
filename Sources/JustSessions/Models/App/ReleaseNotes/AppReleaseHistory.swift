import Foundation

enum AppReleaseHistory {
    /// The small bundled catalog loads once and works offline, including in the packaged app.
    static let bundled: Result<[AppReleaseNotes], Error> = Result { try load() }

    static func load(from resourceBundle: Bundle = AppLocalization.resourceBundle) throws -> [AppReleaseNotes] {
        guard let catalogURL = resourceBundle.url(forResource: "releases", withExtension: "json", subdirectory: "ReleaseNotes") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([AppReleaseNotes].self, from: Data(contentsOf: catalogURL))
    }
}
