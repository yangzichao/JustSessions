import Foundation
import Testing
@testable import JustSessions

struct RemoteHostModelTests {
    @Test func hostListAcceptsSSHDestinationsAndRejectsUnsafeOnes() {
        var hostList = RemoteHostList()
        let addResults = [
            "  devbox  ", "me@devbox.example.com", "devbox", "-oProxyCommand=evil", "two words", "host/path", "   ",
        ].map { hostList.add($0) }
        #expect(addResults == [true, true, false, false, false, false, false])
        #expect(hostList.hosts == ["devbox", "me@devbox.example.com"])

        hostList.remove("devbox")
        #expect(hostList.hosts == ["me@devbox.example.com"])
    }

    @Test func remoteProjectKeyRoundTripsAndStaysApartFromLocalPaths() throws {
        let key = RemoteProjectKey.key(host: "me@devbox", projectPath: "/home/me/paper")
        #expect(key == "ssh://me@devbox/home/me/paper")
        let location = try #require(RemoteProjectKey.location(ofKey: key))
        #expect(location.host == "me@devbox")
        #expect(location.projectPath == "/home/me/paper")
        #expect(RemoteProjectKey.copyablePath(ofKey: key) == "me@devbox:/home/me/paper")
        #expect(RemoteProjectKey.location(ofKey: "/Users/me/paper") == nil)
        #expect(RemoteProjectKey.copyablePath(ofKey: "/Users/me/paper") == "/Users/me/paper")
    }

    @Test func remoteConversationsGroupByHostAndCannotBeDeletedHere() {
        let sessionID = UUID().uuidString
        let local = Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: "/Users/me/paper",
            suggestedTitle: "Local",
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl")
        )
        let remote = local.onRemoteHost("devbox")

        #expect(local.id != remote.id)
        #expect(remote.projectDirectoryKey == "ssh://devbox/Users/me/paper")
        #expect(remote.isProjectAvailable)
        #expect(!remote.supportsDeletionFromLauncher)
        #expect(remote.withSuggestedTitle("Renamed").remoteHost == "devbox")

        let groups = ProjectConversationGroup.grouped([local, remote])
        #expect(groups.count == 2)
        let remoteGroup = groups.first { $0.remoteLocation != nil }
        #expect(remoteGroup?.remoteLocation?.host == "devbox")
        #expect(remoteGroup?.folderName == "paper")
        #expect(remoteGroup?.isProjectAvailable == false)
    }
}
