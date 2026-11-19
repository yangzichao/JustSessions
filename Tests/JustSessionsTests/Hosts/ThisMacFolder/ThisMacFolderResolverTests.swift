import Foundation
import Testing

@testable import JustSessions

struct ThisMacFolderResolverTests {
    @Test func anExistingFolderIsReturnedStandardized() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectFolder = root.appendingPathComponent("app")
        try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)

        let resolvedPath = try ThisMacFolderResolver.resolvedPath(of: root.path + "/app/../app/")

        #expect(resolvedPath == projectFolder.standardizedFileURL.path)
    }

    @Test func tildeAndRelativePathsAreInTheHomeFolder() {
        let home = NSHomeDirectory()
        #expect(ThisMacFolderResolver.absolutePath(of: "~") == home)
        #expect(ThisMacFolderResolver.absolutePath(of: "~/code/app") == home + "/code/app")
        #expect(ThisMacFolderResolver.absolutePath(of: "code/app") == home + "/code/app")
    }

    @Test func aMissingFolderIsReportedAndNotCreated() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let missingFolder = root.appendingPathComponent("gone").path

        #expect(throws: ThisMacFolderResolutionError.missingFolder(folder: missingFolder)) {
            try ThisMacFolderResolver.resolvedPath(of: missingFolder)
        }
        #expect(!FileManager.default.fileExists(atPath: missingFolder))
    }

    @Test func aMissingFolderIsCreatedWithItsParentsWhenAsked() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let newFolder = root.appendingPathComponent("new/app")

        let resolvedPath = try ThisMacFolderResolver.resolvedPath(of: newFolder.path, creatingMissingFolder: true)

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: newFolder.path, isDirectory: &isDirectory) && isDirectory.boolValue)
        #expect(resolvedPath == newFolder.standardizedFileURL.path)
    }

    @Test func aFileIsNotAFolderEvenWhenAskedToCreateOne() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("notes.txt")
        try "notes".write(to: file, atomically: true, encoding: .utf8)

        #expect(throws: ThisMacFolderResolutionError.notAFolder(folder: file.path)) {
            try ThisMacFolderResolver.resolvedPath(of: file.path, creatingMissingFolder: true)
        }
    }

    @Test func aFolderThatCannotBeCreatedIsReported() throws {
        let root = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
        let newFolder = root.appendingPathComponent("new").path

        #expect(throws: ThisMacFolderResolutionError.couldNotCreateFolder(folder: newFolder)) {
            try ThisMacFolderResolver.resolvedPath(of: newFolder, creatingMissingFolder: true)
        }
    }
}
