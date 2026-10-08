import Foundation
import Testing
@testable import JustSessions

struct NativeCLICommandResolverTests {
    @Test func usesExecutableAndProjectDirectoryWithoutShellQuoting() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binaryDirectory = root.appendingPathComponent("bin with spaces")
        let projectDirectory = root.appendingPathComponent("it's a project")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let executable = binaryDirectory.appendingPathComponent("claude")
        try writeExecutableScript("#!/bin/sh\nexit 0\n", to: executable)
        let conversation = Conversation(
            provider: .claude,
            sessionID: UUID().uuidString,
            projectPath: projectDirectory.path,
            suggestedTitle: "Example",
            updatedAt: .now,
            sourceFile: root.appendingPathComponent("session.jsonl")
        )
        let resolver = NativeCLICommandResolver(
            searchDirectories: [binaryDirectory.path],
            inheritedEnvironment: ["HOME": root.path, "PATH": binaryDirectory.path]
        )

        let command = try resolver.resolve(conversation: conversation, action: .branch, adapter: ClaudeAdapter())
        #expect(command.executablePath == executable.path)
        #expect(command.workingDirectory == projectDirectory.path)
        #expect(command.arguments == ["--resume", conversation.sessionID, "--fork-session"])
        #expect(command.environment.contains("TERM=xterm-256color"))
    }

    @Test func newSessionStartsBareNativeCLIInSelectedProject() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binaryDirectory = root.appendingPathComponent("bin")
        let projectDirectory = root.appendingPathComponent("new project")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        for executableName in ConversationProvider.allCases.map(\.executableName) {
            let executable = binaryDirectory.appendingPathComponent(executableName)
            try writeExecutableScript("#!/bin/sh\nexit 0\n", to: executable)
        }
        let resolver = NativeCLICommandResolver(searchDirectories: [binaryDirectory.path])

        for provider in ConversationProvider.allCases {
            let command = try resolver.resolveNewSession(provider: provider, projectPath: projectDirectory.path)
            // Codex names its thread in the terminal title only when asked; see `CodexThreadTitle`.
            #expect(command.arguments == (provider == .codex ? CodexThreadTitle.launchArguments : []))
            #expect(command.workingDirectory == projectDirectory.path)
            let expectedExecutable = switch provider {
            case .claude: "claude"
            case .codex: "codex"
            case .antigravity: "agy"
            case .kiro: "kiro-cli"
            case .opencode: "opencode"
            case .pi: "pi"
            }
            #expect(command.executablePath == binaryDirectory.appendingPathComponent(expectedExecutable).path)
        }
    }

    @Test func piAndOpenCodeStartWithTheExtensionThatReportsTheirSession() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binaryDirectory = root.appendingPathComponent("bin")
        let projectDirectory = root.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        for executableName in ["pi", "opencode", "claude"] {
            try writeExecutableScript("#!/bin/sh\nexit 0\n", to: binaryDirectory.appendingPathComponent(executableName))
        }
        let reporting = LiveSessionReporting(directory: root.appendingPathComponent("reporting"))
        let resolver = NativeCLICommandResolver(searchDirectories: [binaryDirectory.path], liveSessionReporting: reporting)
        let reportsVariable = "\(LiveSessionReporting.reportsDirectoryVariable)=\(reporting.reportsDirectory.path)"
        let piExtension = reporting.directory.appendingPathComponent("pi/\(PiLiveSessionExtension.fileName)").path
        let piConversation = Conversation.fixture(provider: .pi, projectPath: projectDirectory.path)

        let resumedPi = try resolver.resolve(conversation: piConversation, action: .resume, adapter: PiAdapter())
        #expect(resumedPi.arguments == ["--extension", piExtension, "--session", piConversation.sessionID])
        #expect(resumedPi.environment.contains(reportsVariable))

        let newOpenCode = try resolver.resolveNewSession(provider: .opencode, projectPath: projectDirectory.path)
        #expect(newOpenCode.arguments.isEmpty)
        #expect(newOpenCode.environment.contains(reportsVariable))
        #expect(newOpenCode.environment.contains("OPENCODE_TUI_CONFIG=\(reporting.directory.appendingPathComponent("opencode/tui.json").path)"))

        let newClaude = try resolver.resolveNewSession(provider: .claude, projectPath: projectDirectory.path)
        #expect(newClaude.arguments.isEmpty)
        #expect(!newClaude.environment.contains(reportsVariable))
    }
}
