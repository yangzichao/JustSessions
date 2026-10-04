import Foundation
import Testing
@testable import JustSessions

struct FullDiskAccessProbeTests {
    @Test func aReadableProtectedFileMeansAllowed() throws {
        let folder = try TemporaryProbeFolder()
        defer { folder.remove() }
        let readable = try folder.file(named: "readable")
        #expect(FullDiskAccessProbe(protectedFiles: [readable]).status() == .allowed)
    }

    @Test func aRefusedOpenMeansNotAllowed() throws {
        let folder = try TemporaryProbeFolder()
        defer { folder.remove() }
        let refused = try folder.file(named: "refused", permissions: 0o000)
        #expect(FullDiskAccessProbe(protectedFiles: [refused]).status() == .notAllowed)
    }

    @Test func aMissingFileLeavesItToTheNextOne() throws {
        let folder = try TemporaryProbeFolder()
        defer { folder.remove() }
        let missing = folder.path + "/missing"
        let refused = try folder.file(named: "refused", permissions: 0o000)
        #expect(FullDiskAccessProbe(protectedFiles: [missing, refused]).status() == .notAllowed)
        #expect(FullDiskAccessProbe(protectedFiles: [missing]).status() == .unknown)
    }
}

private struct TemporaryProbeFolder {
    let path: String

    init() throws {
        path = FileManager.default.temporaryDirectory.appendingPathComponent("FullDiskAccessProbe-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    func file(named name: String, permissions: Int = 0o600) throws -> String {
        let filePath = path + "/" + name
        #expect(FileManager.default.createFile(atPath: filePath, contents: Data("x".utf8)))
        try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: filePath)
        return filePath
    }

    func remove() {
        try? FileManager.default.removeItem(atPath: path)
    }
}
