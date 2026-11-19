// demo-driver: inspects the demo app through Accessibility and performs scripted, human-paced input.
// Every input step first checks that the demo app is frontmost and aborts otherwise.
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// Set by Scripts/DemoVideo/settings.sh.
let demoBundleIdentifier = ProcessInfo.processInfo.environment["DEMO_BUNDLE_IDENTIFIER"] ?? ""
let demoExecutable = ProcessInfo.processInfo.environment["DEMO_APP_EXECUTABLE"] ?? ""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func demoApplication() -> NSRunningApplication {
    guard let application = NSRunningApplication(processIdentifier: demoProcessIdentifier())
    else { fail("demo app is not running") }
    return application
}

func requireDemoFrontmost() {
    let frontmost = NSWorkspace.shared.frontmostApplication
    if frontmost?.bundleIdentifier != demoBundleIdentifier && frontmost?.processIdentifier != demoProcessIdentifier() {
        fail("ABORT: frontmost app is \(frontmost?.bundleIdentifier ?? "none"), not the demo app")
    }
}

// MARK: - Accessibility

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func frame(of element: AXUIElement) -> CGRect? {
    guard let positionValue = attribute(element, kAXPositionAttribute), let sizeValue = attribute(element, kAXSizeAttribute)
    else { return nil }
    var position = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    return CGRect(origin: position, size: size)
}

func describe(_ element: AXUIElement) -> String {
    let fields = [
        kAXRoleAttribute, kAXSubroleAttribute, kAXTitleAttribute, kAXDescriptionAttribute,
        kAXIdentifierAttribute, kAXValueAttribute, kAXHelpAttribute,
    ]
    var parts: [String] = []
    for field in fields {
        if let value = attribute(element, field) as? String, !value.isEmpty {
            let short = value.count > 60 ? String(value.prefix(60)) + "…" : value
            parts.append("\(field.replacingOccurrences(of: "AX", with: ""))=\(short.replacingOccurrences(of: "\n", with: " "))")
        }
    }
    if let rect = frame(of: element) {
        parts.append(String(format: "@(%.0f,%.0f %.0fx%.0f)", rect.minX, rect.minY, rect.width, rect.height))
    }
    return parts.joined(separator: " ")
}

func children(of element: AXUIElement) -> [AXUIElement] {
    (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func dump(_ element: AXUIElement, depth: Int, maximumDepth: Int) {
    print(String(repeating: "  ", count: depth) + describe(element))
    if depth < maximumDepth { for child in children(of: element) { dump(child, depth: depth + 1, maximumDepth: maximumDepth) } }
}

/// LaunchServices lists the exec'd demo app with pid -1, so the real pid comes from the process table.
func demoProcessIdentifier() -> pid_t {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-f", demoExecutable]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    guard let identifier = output.split(separator: "\n").first.flatMap({ pid_t($0) }) else { fail("demo app is not running") }
    return identifier
}

/// The app's workspace windows, front to back. Small helper windows (the app shows one at the window buttons while
/// the screen is being recorded) are left out so window 0 is always the front workspace window.
func windows() -> [AXUIElement] {
    let application = AXUIElementCreateApplication(demoProcessIdentifier())
    let all = (attribute(application, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    return all.filter { attribute($0, kAXSubroleAttribute) as? String == "AXStandardWindow" }
}

/// Finds the first element whose title, description, value, or identifier contains `text`, breadth first.
/// The menu bar is skipped, so searching the whole app reaches context menus and alerts, not File or Window.
func find(_ text: String, role: String?, in root: AXUIElement) -> AXUIElement? {
    var queue = [root]
    while !queue.isEmpty {
        let element = queue.removeFirst()
        let elementRole = attribute(element, kAXRoleAttribute) as? String
        if elementRole == "AXMenuBar" { continue }
        if role == nil || elementRole == role {
            for field in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXIdentifierAttribute] {
                if let value = attribute(element, field) as? String, value.contains(text) { return element }
            }
        }
        queue.append(contentsOf: children(of: element))
    }
    return nil
}

// MARK: - Input

var cursor: CGPoint { CGEvent(source: nil)?.location ?? .zero }
let eventSource = CGEventSource(stateID: .hidSystemState)

func post(_ type: CGEventType, at point: CGPoint, button: CGMouseButton = .left, clickState: Int64 = 1) {
    let event = CGEvent(mouseEventSource: eventSource, mouseType: type, mouseCursorPosition: point, mouseButton: button)!
    event.setIntegerValueField(.mouseEventClickState, value: clickState)
    event.post(tap: .cghidEventTap)
}

func easeInOut(_ t: Double) -> Double { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }

/// Moves along a slightly curved, eased path at about 120 events a second, the way a hand does.
func glide(to target: CGPoint, duration: Double, dragging: Bool = false) {
    let start = cursor
    let steps = max(2, Int(duration * 120))
    let distance = hypot(target.x - start.x, target.y - start.y)
    let bend = min(40, distance * 0.08)
    let normal = distance > 0 ? CGPoint(x: -(target.y - start.y) / distance, y: (target.x - start.x) / distance) : .zero
    for step in 1...steps {
        let t = easeInOut(Double(step) / Double(steps))
        let arc = sin(Double(step) / Double(steps) * .pi) * bend
        let point = CGPoint(
            x: start.x + (target.x - start.x) * t + normal.x * arc,
            y: start.y + (target.y - start.y) * t + normal.y * arc)
        post(dragging ? .leftMouseDragged : .mouseMoved, at: point)
        usleep(useconds_t(duration / Double(steps) * 1_000_000))
    }
}

func click(at point: CGPoint, count: Int = 1, button: CGMouseButton = .left) {
    let (down, up): (CGEventType, CGEventType) = button == .right ? (.rightMouseDown, .rightMouseUp) : (.leftMouseDown, .leftMouseUp)
    for index in 1...count {
        post(down, at: point, button: button, clickState: Int64(index))
        usleep(70_000)
        post(up, at: point, button: button, clickState: Int64(index))
        usleep(90_000)
    }
}

let keyCodes: [String: CGKeyCode] = [
    "return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53, "left": 123, "right": 124, "down": 125, "up": 126,
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
    "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
    "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "\\": 42, ",": 43, "/": 44, ".": 47,
    "[": 33, "]": 30,
]

func pressKey(_ combination: String) {
    var flags: CGEventFlags = []
    var keyName = combination
    let parts = combination.split(separator: "+").map(String.init)
    if parts.count > 1 {
        keyName = parts.last!
        for modifier in parts.dropLast() {
            switch modifier {
            case "cmd": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "alt": flags.insert(.maskAlternate)
            case "ctrl": flags.insert(.maskControl)
            default: fail("unknown modifier \(modifier)")
            }
        }
    }
    guard let code = keyCodes[keyName] else { fail("unknown key \(keyName)") }
    for isDown in [true, false] {
        let event = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: isDown)!
        event.flags = flags
        event.post(tap: .cghidEventTap)
        usleep(40_000)
    }
}

func typeText(_ text: String, charactersPerSecond: Double) {
    for character in text {
        var units = Array(String(character).utf16)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: isDown)!
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            event.post(tap: .cghidEventTap)
        }
        usleep(useconds_t(1_000_000 / charactersPerSecond * Double.random(in: 0.7...1.3)))
    }
}

// MARK: - Script

/// Resolves a step's target: explicit "x","y", or an element found by "find" text (optionally "role", "window",
/// or "scope": "app" to search menus and alerts too), with "dx","dy" offsets from the element's center
/// (or "anchor": "left"/"right" for its edges). Waits up to "timeout" seconds (default 3) for the element to appear.
func target(of step: [String: Any]) -> CGPoint {
    if let x = step["x"] as? Double, let y = step["y"] as? Double { return CGPoint(x: x, y: y) }
    guard let text = step["find"] as? String else { fail("step needs x/y or find: \(step)") }
    let deadline = Date().addingTimeInterval(step["timeout"] as? Double ?? 3)
    var found: (AXUIElement, CGRect)?
    repeat {
        let root: AXUIElement?
        if step["scope"] as? String == "app" {
            root = AXUIElementCreateApplication(demoProcessIdentifier())
        } else {
            let windowList = windows()
            let windowIndex = step["window"] as? Int ?? 0
            root = windowIndex < windowList.count ? windowList[windowIndex] : nil
        }
        if let root, let element = find(text, role: step["role"] as? String, in: root), let rect = frame(of: element),
            rect.width > 0, rect.minX.isFinite
        {
            found = (element, rect)
        } else {
            usleep(150_000)
        }
    } while found == nil && Date() < deadline
    guard let (_, rect) = found else {
        let windowList = windows()
        fail(
            "element not found: \(text) (pid \(demoProcessIdentifier()), \(windowList.count) windows: "
                + windowList.map(describe).joined(separator: "; ") + ")")
    }
    var point = CGPoint(x: rect.midX, y: rect.midY)
    if step["anchor"] as? String == "left" { point.x = rect.minX + 12 }
    if step["anchor"] as? String == "right" { point.x = rect.maxX - 12 }
    point.x += step["dx"] as? Double ?? 0
    point.y += step["dy"] as? Double ?? 0
    return point
}

func log(_ message: String) {
    print(String(format: "%.3f %@", Date().timeIntervalSince1970, message))
    fflush(stdout)
}

func run(script path: String) {
    guard let data = FileManager.default.contents(atPath: path),
        let steps = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { fail("cannot read script \(path)") }
    for step in steps {
        let action = step["do"] as? String ?? ""
        let speed = step["speed"] as? Double ?? 0.55
        if action != "wait" && action != "mark" && action != "activate" { requireDemoFrontmost() }
        log("\(action) \(step["find"] ?? step["text"] ?? step["key"] ?? "")")
        switch action {
        case "activate":
            demoApplication().activate()
            usleep(400_000)
        case "wait": usleep(useconds_t((step["seconds"] as? Double ?? 0.5) * 1_000_000))
        case "mark": break
        case "move": glide(to: target(of: step), duration: speed)
        case "click", "doubleclick", "rightclick":
            let point = target(of: step)
            glide(to: point, duration: speed)
            usleep(120_000)
            click(at: point, count: action == "doubleclick" ? 2 : 1, button: action == "rightclick" ? .right : .left)
        case "drag":
            let start = target(of: step)
            guard let end = step["to"] as? [String: Any] else { fail("drag needs to") }
            let endPoint = target(of: end)
            glide(to: start, duration: speed)
            usleep(150_000)
            post(.leftMouseDown, at: start)
            usleep(250_000)
            glide(to: CGPoint(x: start.x + 6, y: start.y + 14), duration: 0.12, dragging: true)
            glide(to: endPoint, duration: step["dragSpeed"] as? Double ?? 0.9, dragging: true)
            usleep(250_000)
            post(.leftMouseUp, at: endPoint)
        case "type": typeText(step["text"] as? String ?? "", charactersPerSecond: step["cps"] as? Double ?? 14)
        case "key": pressKey(step["key"] as? String ?? "")
        default: fail("unknown action \(action)")
        }
    }
    log("done")
}

// MARK: - Commands

let arguments = CommandLine.arguments
if demoBundleIdentifier.isEmpty || demoExecutable.isEmpty {
    fail("Run this through Scripts/DemoVideo/demo-video, which sets DEMO_BUNDLE_IDENTIFIER and DEMO_APP_EXECUTABLE.")
}
switch arguments.count > 1 ? arguments[1] : "" {
case "windows":
    for (index, window) in windows().enumerated() { print(index, describe(window)) }
case "dump":
    let windowIndex = arguments.count > 2 ? Int(arguments[2])! : 0
    dump(windows()[windowIndex], depth: 0, maximumDepth: arguments.count > 3 ? Int(arguments[3])! : 30)
case "setframe":
    let values = arguments[3...6].map { Double($0)! }
    let window = windows()[Int(arguments[2])!]
    var position = CGPoint(x: values[0], y: values[1])
    var size = CGSize(width: values[2], height: values[3])
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &position)!)
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
    print(describe(window))
case "activate":
    demoApplication().activate()
case "windowids":
    let windowList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    for info in windowList
    where (info[kCGWindowOwnerPID as String] as? pid_t) == demoProcessIdentifier()
        && (info[kCGWindowLayer as String] as? Int) == 0
    {
        print(info[kCGWindowNumber as String]!, info[kCGWindowBounds as String]!)
    }
case "press":
    // Presses a control through Accessibility, without moving the pointer or bringing the app forward.
    guard let element = find(arguments[2], role: arguments.count > 3 ? arguments[3] : nil, in: windows()[0])
    else { fail("element not found: \(arguments[2])") }
    print(AXUIElementPerformAction(element, kAXPressAction as CFString).rawValue, describe(element))
case "showmenu":
    // Opens an element's context menu through Accessibility, then lists the menu's items.
    guard let element = find(arguments[2], role: arguments.count > 3 ? arguments[3] : nil, in: windows()[0])
    else { fail("element not found: \(arguments[2])") }
    print(AXUIElementPerformAction(element, kAXShowMenuAction as CFString).rawValue, describe(element))
    usleep(600_000)
    let application = AXUIElementCreateApplication(demoProcessIdentifier())
    var queue = [application]
    while !queue.isEmpty {
        let candidate = queue.removeFirst()
        if attribute(candidate, kAXRoleAttribute) as? String == "AXMenu" {
            dump(candidate, depth: 0, maximumDepth: 3)
            break
        }
        if attribute(candidate, kAXRoleAttribute) as? String != "AXMenuBar" { queue.append(contentsOf: children(of: candidate)) }
    }
case "locate":
    // Resolves a script step's target without moving the pointer: demo-driver locate '{"find": "Resume"}'
    guard let step = try? JSONSerialization.jsonObject(with: Data(arguments[2].utf8)) as? [String: Any]
    else { fail("locate needs a JSON step") }
    print(target(of: step))
case "setvalue":
    guard let element = find(arguments[2], role: "AXTextField", in: windows()[0]) else { fail("field not found") }
    print(AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, arguments[3] as CFString).rawValue)
case "frontmost":
    print(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")
case "cursor":
    print(cursor)
case "run":
    run(script: arguments[2])
default:
    fail("usage: demo-driver windows | dump <window> [depth] | setframe <window> x y w h | activate | frontmost | run <script.json>")
}
