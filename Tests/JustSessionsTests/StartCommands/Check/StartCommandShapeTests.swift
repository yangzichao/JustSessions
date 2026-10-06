import Testing
@testable import JustSessions

/// A start command is read as the shell reads it, without running it, to find the program it starts.
struct StartCommandShapeTests {
    struct ShapeCase: Sendable, CustomTestStringConvertible {
        let command: String
        let shape: StartCommandShape
        var testDescription: String { command }
    }

    static let shapeCases = [
        ShapeCase(
            command: #"~/.toolbox/bin/claude --aws-profile "xiliuz-dev" --dangerously-skip-permissions"#,
            shape: .program("~/.toolbox/bin/claude")
        ),
        ShapeCase(command: "claude", shape: .program("claude")),
        ShapeCase(command: #"GREETING=hi ~/tools/my-claude --aws-profile "dev box""#, shape: .program("~/tools/my-claude")),
        ShapeCase(command: #""/Applications/My Tools/claude" --verbose"#, shape: .program("/Applications/My Tools/claude")),
        ShapeCase(command: #"my\ claude"#, shape: .program("my claude")),
        ShapeCase(command: "'kiro-cli' chat --trust-all-tools", shape: .program("kiro-cli")),
        // Separators and expansions in the arguments do not change the program.
        ShapeCase(command: #"claude --append-system-prompt "a; b | c""#, shape: .program("claude")),
        ShapeCase(command: "claude --tag=a#b", shape: .program("claude")),
        ShapeCase(command: "claude --model $(cat ~/.model; echo)", shape: .program("claude")),
        ShapeCase(command: "FOO=bar", shape: .noProgram),
        ShapeCase(command: "$HOME/bin/claude", shape: .programKnownOnlyWhenItRuns),
        ShapeCase(command: #""$(brew --prefix)/bin/claude""#, shape: .programKnownOnlyWhenItRuns),
        ShapeCase(command: "./bin/claude", shape: .programKnownOnlyWhenItRuns),
        ShapeCase(command: "~someone/bin/claude", shape: .programKnownOnlyWhenItRuns),
        ShapeCase(command: "-i claude", shape: .programKnownOnlyWhenItRuns),
        ShapeCase(command: #"claude --aws-profile "dev"#, shape: .unclosedQuote),
        ShapeCase(command: "claude --name 'dev", shape: .unclosedQuote),
        ShapeCase(command: #"claude \"#, shape: .unclosedQuote),
        ShapeCase(command: "claude --model $(cat ~/.model", shape: .unclosedQuote),
        ShapeCase(command: "claude; rm -rf ~/tmp", shape: .shellOperator(";")),
        ShapeCase(command: "cd ~/api && claude", shape: .shellOperator("&")),
        ShapeCase(command: "claude | tee log", shape: .shellOperator("|")),
        ShapeCase(command: "claude > log", shape: .shellOperator(">")),
        // The app's arguments would land in the comment.
        ShapeCase(command: "claude # mine", shape: .shellOperator("#")),
    ]

    @Test(arguments: shapeCases)
    func readsTheProgram(_ shapeCase: ShapeCase) {
        #expect(StartCommandShape(shapeCase.command) == shapeCase.shape)
    }
}
