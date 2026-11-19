import Foundation

enum StartCommandShape: Equatable {
    case program(String)
    case programKnownOnlyWhenItRuns
    case noProgram
    case unclosedQuote
    case shellOperator(String)

    init(_ command: String) {
        let words: [Word]
        do {
            words = try Self.words(in: Array(command))
        } catch ReadingProblem.unclosedQuote {
            self = .unclosedQuote
            return
        } catch ReadingProblem.shellOperator(let shellOperator) {
            self = .shellOperator(shellOperator)
            return
        } catch {
            self = .unclosedQuote
            return
        }
        // `env` takes every word with `=` before the program as a variable to set.
        guard let programWord = words.first(where: { !$0.text.contains("=") }) else {
            self = .noProgram
            return
        }
        let program = programWord.text
        let isPathFromRootOrHome = program.hasPrefix("/") || program.hasPrefix("~/")
        let isNameOnPath = !program.contains("/") && !program.hasPrefix("~") && !program.hasPrefix("-")
        self =
            !programWord.hasExpansion && (isPathFromRootOrHome || isNameOnPath)
            ? .program(program)
            : .programKnownOnlyWhenItRuns
    }

    private struct Word {
        var text = ""
        var hasExpansion = false
    }

    private enum ReadingProblem: Error {
        case unclosedQuote
        case shellOperator(String)
    }

    private static let shellOperators: Set<Character> = [";", "&", "|", "<", ">", "(", ")"]

    private static func words(in characters: [Character]) throws -> [Word] {
        var words: [Word] = []
        var word = Word()
        var isInWord = false
        var index = 0
        while index < characters.count {
            let character = characters[index]
            switch character {
            case " ", "\t":
                if isInWord { words.append(word) }
                word = Word()
                isInWord = false
                index += 1
                continue
            case "\\":
                guard index + 1 < characters.count else { throw ReadingProblem.unclosedQuote }
                index += 1
                word.text.append(characters[index])
            case "'":
                let closingIndex = try indexOf("'", in: characters, after: index)
                word.text.append(contentsOf: characters[(index + 1)..<closingIndex])
                index = closingIndex
            case "\"":
                index = try readDoubleQuoted(characters, openingAt: index, into: &word)
            case "$":
                word.hasExpansion = true
                word.text.append(character)
                if index + 1 < characters.count, characters[index + 1] == "(" {
                    let closingIndex = try indexOfClosingParenthesis(in: characters, openingAt: index + 1)
                    word.text.append(contentsOf: characters[(index + 1)...closingIndex])
                    index = closingIndex
                }
            case "`":
                let closingIndex = try indexOf("`", in: characters, after: index)
                word.hasExpansion = true
                word.text.append(contentsOf: characters[index...closingIndex])
                index = closingIndex
            case "#" where !isInWord:
                throw ReadingProblem.shellOperator("#")
            case _ where shellOperators.contains(character):
                throw ReadingProblem.shellOperator(String(character))
            default:
                word.text.append(character)
            }
            isInWord = true
            index += 1
        }
        if isInWord { words.append(word) }
        return words
    }

    private static func readDoubleQuoted(_ characters: [Character], openingAt openingIndex: Int, into word: inout Word) throws -> Int {
        var index = openingIndex + 1
        while index < characters.count {
            let character = characters[index]
            if character == "\"" { return index }
            if character == "\\", index + 1 < characters.count, "$`\"\\".contains(characters[index + 1]) {
                index += 1
                word.text.append(characters[index])
            } else {
                if character == "$" || character == "`" { word.hasExpansion = true }
                word.text.append(character)
            }
            index += 1
        }
        throw ReadingProblem.unclosedQuote
    }

    private static func indexOf(_ closingCharacter: Character, in characters: [Character], after openingIndex: Int) throws -> Int {
        guard let closingIndex = characters[(openingIndex + 1)...].firstIndex(of: closingCharacter) else {
            throw ReadingProblem.unclosedQuote
        }
        return closingIndex
    }

    private static func indexOfClosingParenthesis(in characters: [Character], openingAt openingIndex: Int) throws -> Int {
        var depth = 0
        for index in openingIndex..<characters.count {
            if characters[index] == "(" { depth += 1 }
            if characters[index] == ")" {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        throw ReadingProblem.unclosedQuote
    }
}
