import Foundation

extension AttributedStringProtocol {
    /// The text without its attributes. Built with the macOS 26.5 SDK, which the release builds use,
    /// `String(text.characters)` resolves to the standard library's generic initializer, which reads one character at a
    /// time: about 100 times slower on transcript text. The slice overload calls Foundation's own conversion with any SDK.
    var plainText: String { String(characters[...]) }
}
