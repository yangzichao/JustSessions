import SwiftUI
import UniformTypeIdentifiers

/// Copies colors from iTerm2's default profile or from an .itermcolors file. Nothing is read until one is chosen.
struct TerminalColorsImportMenu: View {
    let onImport: (Result<ImportedTerminalColors, TerminalColorsImportError>) -> Void

    @State private var isChoosingFile = false

    private static let colorPresetFileType = UTType(filenameExtension: "itermcolors") ?? .propertyList

    var body: some View {
        Menu("Import") {
            Button("iTerm2 Default Profile") {
                onImport(Self.importing { try ITermProfileColorsImporter.importDefaultProfile() })
            }
            Button("iTerm2 Color Preset File…") { isChoosingFile = true }
        }
        .fixedSize()
        .help("Copies the colors once. JustSessions doesn't read iTerm2's settings again.")
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [Self.colorPresetFileType]) { result in
            guard case .success(let url) = result else {
                onImport(.failure(.unreadableFile))
                return
            }
            let isAccessingFile = url.startAccessingSecurityScopedResource()
            defer { if isAccessingFile { url.stopAccessingSecurityScopedResource() } }
            onImport(Self.importing { try ITermColorsFileImporter.importFile(at: url) })
        }
    }

    private static func importing(
        _ read: () throws -> ImportedTerminalColors
    ) -> Result<ImportedTerminalColors, TerminalColorsImportError> {
        do {
            return .success(try read())
        } catch let error as TerminalColorsImportError {
            return .failure(error)
        } catch {
            return .failure(.unreadableFile)
        }
    }
}
