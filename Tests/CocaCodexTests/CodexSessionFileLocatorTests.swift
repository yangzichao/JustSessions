import Foundation
import Testing
@testable import CocaCodex

struct CodexSessionFileLocatorTests {
    @Test func findsTheOpenCodexRolloutFile() {
        let output = """
        p93163
        fcwd
        n/Users/example/workplace/project
        f65
        n/Users/example/.codex/sessions/2026/09/24/rollout-2026-09-24T07-28-33-01a0d3d1-6f20-7f03-a220-642217461510.jsonl
        """

        #expect(CodexSessionFileLocator.sessionFile(in: output)?.lastPathComponent
            == "rollout-2026-09-24T07-28-33-01a0d3d1-6f20-7f03-a220-642217461510.jsonl")
        #expect(CodexSessionFileLocator.sessionFile(in: "p93163\nfcwd\nn/Users/example/project\n") == nil)
    }
}
