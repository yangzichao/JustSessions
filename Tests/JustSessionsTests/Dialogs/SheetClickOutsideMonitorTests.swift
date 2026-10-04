import AppKit
import Testing
@testable import JustSessions

@MainActor
struct SheetClickOutsideMonitorTests {
    @Test func onlyAClickOnTheCoveredWindowCountsAsOutsideTheSheet() throws {
        let windows = SheetWindows()
        defer { windows.close() }
        let contentPoint = CGPoint(x: 40, y: 40)
        let titleBarPoint = CGPoint(x: 300, y: windows.parent.frame.height - 5)
        #expect(!SheetClickOutsideMonitor.isClickOutsideSheet(try windows.click(at: contentPoint, in: windows.parent), in: windows.parent))

        windows.presentSheet()

        #expect(SheetClickOutsideMonitor.isClickOutsideSheet(try windows.click(at: contentPoint, in: windows.parent), in: windows.parent))
        // The tab bar sits in the title bar.
        #expect(SheetClickOutsideMonitor.isClickOutsideSheet(try windows.click(at: titleBarPoint, in: windows.parent), in: windows.parent))
        #expect(!SheetClickOutsideMonitor.isClickOutsideSheet(try windows.click(at: contentPoint, in: windows.sheet), in: windows.parent))
    }

    @Test func aClickOnTheCoveredWindowReachesTheHandlerButOneInTheSheetDoesNot() throws {
        let windows = SheetWindows()
        defer { windows.close() }
        windows.presentSheet()
        var clicksOutside = 0
        let monitor = SheetClickOutsideMonitor(window: windows.parent) {
            clicksOutside += 1
            return true
        }
        defer { monitor.stop() }

        NSApp.sendEvent(try windows.click(at: CGPoint(x: 40, y: 40), in: windows.parent))
        #expect(clicksOutside == 1)

        NSApp.sendEvent(try windows.click(at: CGPoint(x: 40, y: 40), in: windows.sheet))
        #expect(clicksOutside == 1)
    }
}

@MainActor
private final class SheetWindows {
    let parent: NSWindow
    let sheet: NSWindow

    init() {
        _ = NSApplication.shared
        parent = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        sheet = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        for window in [parent, sheet] { window.isReleasedWhenClosed = false }
    }

    func presentSheet() {
        parent.beginSheet(sheet)
    }

    func click(at point: CGPoint, in window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }

    func close() {
        if parent.attachedSheet != nil { parent.endSheet(sheet) }
        sheet.close()
        parent.close()
    }
}
