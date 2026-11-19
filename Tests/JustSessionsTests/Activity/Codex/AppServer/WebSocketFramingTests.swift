import Foundation
import Testing

@testable import JustSessions

struct WebSocketFramingTests {
    private let mask: [UInt8] = [0x37, 0xFA, 0x21, 0x3D]

    @Test func masksWhatTheClientSends() {
        // RFC 6455, section 5.7: a single-frame masked text message of "Hello".
        let frame = WebSocketClientFrame.frame(.text, payload: Data("Hello".utf8), mask: mask)

        #expect([UInt8](frame) == [0x81, 0x85, 0x37, 0xFA, 0x21, 0x3D, 0x7F, 0x9F, 0x4D, 0x51, 0x58])
    }

    @Test func longerPayloadsGetLongerLengths() {
        let medium = WebSocketClientFrame.frame(.text, payload: Data(count: 300), mask: mask)
        let large = WebSocketClientFrame.frame(.text, payload: Data(count: 70_000), mask: mask)

        #expect([UInt8](medium.prefix(4)) == [0x81, 0x80 | 126, 0x01, 0x2C])
        #expect(medium.count == 4 + 4 + 300)
        #expect([UInt8](large.prefix(10)) == [0x81, 0x80 | 127, 0, 0, 0, 0, 0, 0x01, 0x11, 0x70])
        #expect(large.count == 10 + 4 + 70_000)
    }

    @Test func readsWhatTheServerSendsOnceItIsWhole() throws {
        var reader = WebSocketMessageReader()
        let hello: [UInt8] = [0x81, 0x05] + Array("Hello".utf8)
        reader.append(Data(hello.prefix(4)))
        #expect(try reader.nextMessage() == nil)

        reader.append(Data(hello.dropFirst(4)))
        #expect(try reader.nextMessage() == .text(Data("Hello".utf8)))
        #expect(try reader.nextMessage() == nil)
    }

    @Test func joinsFragmentsAndSkipsPongsBetweenThem() throws {
        var reader = WebSocketMessageReader()
        // RFC 6455, section 5.7: "Hel", then "lo", with a pong between the two and a ping after them.
        reader.append(Data([0x01, 0x03] + Array("Hel".utf8)))
        reader.append(Data([0x8A, 0x00]))
        reader.append(Data([0x80, 0x02] + Array("lo".utf8)))
        reader.append(Data([0x89, 0x05] + Array("Hello".utf8)))

        #expect(try reader.nextMessage() == .text(Data("Hello".utf8)))
        #expect(try reader.nextMessage() == .ping(Data("Hello".utf8)))
    }

    @Test func readsMaskedFramesLongLengthsAndTheClose() throws {
        var reader = WebSocketMessageReader()
        reader.append(WebSocketClientFrame.frame(.text, payload: Data(repeating: 0x61, count: 300), mask: mask))
        reader.append(Data([0x88, 0x00]))

        #expect(try reader.nextMessage() == .text(Data(repeating: 0x61, count: 300)))
        #expect(try reader.nextMessage() == .close)
    }

    @Test func refusesAFrameLongerThanItKeeps() {
        var reader = WebSocketMessageReader()
        reader.append(Data([0x81, 127, 0, 0, 0, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF]))

        #expect(throws: WebSocketMessageReader.ReadError.frameTooLong) { try reader.nextMessage() }
    }

    @Test func acceptsOnlyASwitchToWebSocket() {
        let request = String(decoding: WebSocketClientFrame.upgradeRequest(key: "dGhlIHNhbXBsZSBub25jZQ=="), as: UTF8.self)

        #expect(request.hasPrefix("GET / HTTP/1.1\r\n"))
        #expect(request.contains("\r\nUpgrade: websocket\r\n"))
        #expect(request.contains("\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"))
        #expect(request.hasSuffix("\r\n\r\n"))
        #expect(WebSocketClientFrame.acceptsUpgrade(Data("HTTP/1.1 101 Switching Protocols\r\n\r\n".utf8)))
        #expect(!WebSocketClientFrame.acceptsUpgrade(Data("HTTP/1.1 400 Bad Request\r\n\r\n".utf8)))
    }
}
