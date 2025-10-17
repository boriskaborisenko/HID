import Foundation
import Starscream
import Cocoa

class HookWebSocketClient: WebSocketDelegate {
    var socket: WebSocket!
    private(set) var isConnected: Bool = false
    private var eventQueue = [String]()

    init(url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
        print("🕸️ Connecting to \(url)...")
    }

    func sendEvent(_ json: String) {
        if isConnected {
            socket.write(string: json)
            print("➡️ \(json)")
        } else {
            eventQueue.append(json)
        }
    }

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            isConnected = true
            print("✅ Connected")
            eventQueue.forEach { socket.write(string: $0) }
            eventQueue.removeAll()
        case .disconnected(let reason, let code):
            isConnected = false
            print("❌ Disconnected: \(reason) (\(code))")
        case .error(let err):
            isConnected = false
            print("⚠️ Error: \(String(describing: err))")
        default: break
        }
    }
}

func modifiersFromEvent(_ event: CGEvent) -> [String] {
    var mods = [String]()
    let flags = event.flags
    if flags.contains(.maskCommand)   { mods.append("command") }
    if flags.contains(.maskAlternate) { mods.append("option") }
    if flags.contains(.maskControl)   { mods.append("control") }
    if flags.contains(.maskShift)     { mods.append("shift") }
    return mods
}

let wsClient = HookWebSocketClient(url: URL(string: "ws://192.168.100.62:31337")!) // 💡 заменяй IP на нужный

var lastEscapeTime: CFAbsoluteTime = 0
var lastMouseTime: CFAbsoluteTime = 0
var mouseButtonHeld: String? = nil

let eventMask: CGEventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.keyUp.rawValue) |
    (1 << CGEventType.mouseMoved.rawValue) |
    (1 << CGEventType.leftMouseDown.rawValue) |
    (1 << CGEventType.leftMouseUp.rawValue) |
    (1 << CGEventType.rightMouseDown.rawValue) |
    (1 << CGEventType.rightMouseUp.rawValue)

let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: eventMask,
    callback: { _, type, event, _ in
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var json = ""

        let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
        let x = Int(event.location.x.rounded())
        //let y = Int((screenHeight - event.location.y).rounded())  // 👈 инверсия Y
    let y = Int(event.location.y.rounded())  // 👈 Без инверсии


        let modifiers = modifiersFromEvent(event)
        let modsJSON = modifiers.map { "\"\($0)\"" }.joined(separator: ", ")

        switch type {
        case .keyDown, .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let keyType = (type == .keyDown) ? "keydown" : "keyup"

            if keyType == "keydown" && keyCode == 53 { // ESC
                let now = CFAbsoluteTimeGetCurrent()
                if now - lastEscapeTime < 0.3 {
                    print("👋 Double ESC — exiting.")
                    exit(0)
                } else {
                    lastEscapeTime = now
                }
            }

            json = """
            { "type": "\(keyType)", "key": \(keyCode), "modifiers": [\(modsJSON)], "timestamp": \(timestamp) }
            """

        case .mouseMoved:
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastMouseTime < 0.008 { return nil } // ⏱️ сглаживание
            lastMouseTime = now

            let buttonStateJSON = mouseButtonHeld != nil ? ", \"buttonState\": \"\(mouseButtonHeld!)\"" : ""
            json = """
            { "type": "mousemove", "x": \(x), "y": \(y)\(buttonStateJSON), "timestamp": \(timestamp) }
            """

        case .leftMouseDown:
            mouseButtonHeld = "left"
            json = """
            { "type": "mousedown", "button": "left", "x": \(x), "y": \(y), "timestamp": \(timestamp) }
            """

        case .leftMouseUp:
            mouseButtonHeld = nil
            json = """
            { "type": "mouseup", "button": "left", "x": \(x), "y": \(y), "timestamp": \(timestamp) }
            """

        case .rightMouseDown:
            mouseButtonHeld = "right"
            json = """
            { "type": "mousedown", "button": "right", "x": \(x), "y": \(y), "timestamp": \(timestamp) }
            """

        case .rightMouseUp:
            mouseButtonHeld = nil
            json = """
            { "type": "mouseup", "button": "right", "x": \(x), "y": \(y), "timestamp": \(timestamp) }
            """

        default: break
        }

        if !json.isEmpty {
            wsClient.sendEvent(json)
        }

        return nil
    },
    userInfo: nil
)

guard let eventTap = tap else {
    print("🚫 Failed to create event tap.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

print("🎧 Hook active. Press ESC twice to quit.")
CFRunLoopRun()
