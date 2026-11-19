import Foundation
import Testing

@testable import JustSessions

struct ThisMacTmuxSelectionTests {
    @Test func anOlderDiscoveryCannotOverwriteANewerCommittedServer() {
        let selection = ThisMacTmuxSelection()
        let older = ThisMacTmuxServer(executablePath: "/tmp/older-tmux", environment: [:])
        let newer = ThisMacTmuxServer(executablePath: "/tmp/newer-tmux", environment: [:])

        let olderGeneration = selection.beginProbeGeneration()
        let newerGeneration = selection.beginProbeGeneration()
        selection.commit(newer, generation: newerGeneration)
        selection.commit(older, generation: olderGeneration)

        #expect(selection.server?.executablePath == newer.executablePath)
    }

    @Test func aNewerDiscoveryCanClearAnOlderSelection() {
        let selection = ThisMacTmuxSelection()
        let older = ThisMacTmuxServer(executablePath: "/tmp/older-tmux", environment: [:])

        selection.commit(older, generation: selection.beginProbeGeneration())
        selection.commit(nil, generation: selection.beginProbeGeneration())

        #expect(selection.server == nil)
    }
}
