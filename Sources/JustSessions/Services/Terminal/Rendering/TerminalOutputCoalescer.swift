import Foundation

/// A bounded, ordered backlog for invisible terminals. It drains at 8 Hz, on activation, or before process exit.
/// PTY reads continue normally; large bursts flush immediately instead of growing an unbounded buffer.
@MainActor
final class TerminalOutputCoalescer {
    static let maximumBufferedByteCount = 64 << 10
    private var bytes: [UInt8] = []
    private var scheduledFlush: DispatchWorkItem?
    var isActive = true {
        didSet { if isActive { flush() } }
    }
    var consume: ((ArraySlice<UInt8>) -> Void)?

    func receive(_ incoming: ArraySlice<UInt8>) {
        if isActive {
            consume?(incoming)
            return
        }
        if bytes.count + incoming.count > Self.maximumBufferedByteCount { flush() }
        if incoming.count >= Self.maximumBufferedByteCount {
            consume?(incoming)
            return
        }
        bytes.append(contentsOf: incoming)
        guard scheduledFlush == nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        scheduledFlush = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.125, execute: work)
    }

    func flush() {
        scheduledFlush?.cancel()
        scheduledFlush = nil
        guard !bytes.isEmpty else { return }
        let pending = bytes
        bytes.removeAll(keepingCapacity: true)
        consume?(pending[...])
    }
}
