/// Ghostty reads a cell nothing was written to as a space.
struct TerminalScreenRow {
    let characters: [Character]
    private let startColumns: [Int]
    private let cellCounts: [Int]

    init(_ text: String) {
        characters = Array(text)
        cellCounts = characters.map(TerminalCellWidth.cellCount(of:))
        var startColumns: [Int] = []
        var column = 0
        for cellCount in cellCounts {
            startColumns.append(column)
            column += cellCount
        }
        self.startColumns = startColumns
    }

    var firstTextIndex: Int? { characters.firstIndex { !Self.isBlank($0) } }

    var lastTextIndex: Int? { characters.lastIndex { !Self.isBlank($0) } }

    var textWidth: Int {
        guard let lastTextIndex else { return 0 }
        return startColumns[lastTextIndex] + cellCounts[lastTextIndex]
    }

    func characterIndex(atColumn column: Int) -> Int? {
        characters.indices.first { startColumns[$0] <= column && column < startColumns[$0] + cellCounts[$0] }
    }

    func character(atColumn column: Int) -> Character? {
        characterIndex(atColumn: column).map { characters[$0] }
    }

    var firstTextCharacter: Character? { firstTextIndex.map { characters[$0] } }

    func startColumn(ofCharacterAt index: Int) -> Int {
        startColumns[index]
    }

    func text(fromColumn column: Int) -> (text: String, cellCount: Int) {
        guard let firstIndex = characters.indices.first(where: { startColumns[$0] >= column }),
            let lastTextIndex, lastTextIndex >= firstIndex
        else { return ("", 0) }
        let cellCount = startColumns[lastTextIndex] + cellCounts[lastTextIndex] - startColumns[firstIndex]
        return (String(characters[firstIndex...lastTextIndex]), cellCount)
    }

    func isBlank(beforeColumn column: Int) -> Bool {
        characters.indices.allSatisfy { startColumns[$0] >= column || Self.isBlank(characters[$0]) }
    }

    func wordRange(around index: Int) -> Range<Int>? {
        guard characters.indices.contains(index), !Self.isBlank(characters[index]) else { return nil }
        var lowerBound = index
        while lowerBound > 0, !Self.isBlank(characters[lowerBound - 1]) { lowerBound -= 1 }
        var upperBound = index + 1
        while upperBound < characters.count, !Self.isBlank(characters[upperBound]) { upperBound += 1 }
        return lowerBound..<upperBound
    }

    var firstWordRange: Range<Int>? { firstTextIndex.flatMap(wordRange(around:)) }

    var lastWordRange: Range<Int>? { lastTextIndex.flatMap(wordRange(around:)) }

    static func isBlank(_ character: Character) -> Bool {
        character.isWhitespace
    }
}
