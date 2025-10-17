import NIO
import NIOHTTP1
import NIOWebSocket
import AppKit
import Foundation

final class WebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)
        guard case .text = frame.opcode else { return }

        var buffer = frame.unmaskedData
        if let bytes = buffer.getBytes(at: 0, length: buffer.readableBytes),
           let jsonStr = String(bytes: bytes, encoding: .utf8) {
            print("📥 Received: \(jsonStr)")

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }

            let modifiers = json["modifiers"] as? [String] ?? []

            switch type {
            case "mousemove":
                if let x = json["x"] as? CGFloat,
                   let y = json["y"] as? CGFloat {
                    //let loc = CGPoint(x: x, y: y)
                    let screenHeight = NSScreen.main?.frame.height ?? 900
let loc = CGPoint(x: x, y: screenHeight - y)

                    let buttonState = json["buttonState"] as? String

                    let type: CGEventType = {
                        switch buttonState {
                        case "left": return .leftMouseDragged
                        case "right": return .rightMouseDragged
                        default: return .mouseMoved
                        }
                    }()

                    let b: CGMouseButton = (buttonState == "right") ? .right : .left
                    CGWarpMouseCursorPosition(loc)
                    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: loc, mouseButton: b)
                    event?.post(tap: .cghidEventTap)
                }

            case "mousedown":
                let loc = extractLocation(from: json)
                if let button = json["button"] as? String {
                    let b: CGMouseButton = (button == "right") ? .right : .left
                    let type: CGEventType = (b == .right) ? .rightMouseDown : .leftMouseDown
                    CGWarpMouseCursorPosition(loc)
                    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: loc, mouseButton: b)
                    event?.flags = flagsFrom(modifiers: modifiers)
                    event?.post(tap: .cghidEventTap)
                }

            case "mouseup":
                let loc = extractLocation(from: json)
                if let button = json["button"] as? String {
                    let b: CGMouseButton = (button == "right") ? .right : .left
                    let type: CGEventType = (b == .right) ? .rightMouseUp : .leftMouseUp
                    CGWarpMouseCursorPosition(loc)
                    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: loc, mouseButton: b)
                    event?.flags = flagsFrom(modifiers: modifiers)
                    event?.post(tap: .cghidEventTap)
                }

            case "keydown":
                if let key = json["key"] as? CGKeyCode {
                    let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
                    event?.flags = flagsFrom(modifiers: modifiers)
                    event?.post(tap: .cghidEventTap)
                }

            case "keyup":
                if let key = json["key"] as? CGKeyCode {
                    let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
                    event?.flags = flagsFrom(modifiers: modifiers)
                    event?.post(tap: .cghidEventTap)
                }

            default:
                break
            }
        }
    }

    /// Поддержка извлечения координаты клика, если она есть
    private func extractLocation(from json: [String: Any]) -> CGPoint {
        if let x = json["x"] as? CGFloat,
           let y = json["y"] as? CGFloat {
            //return CGPoint(x: x, y: y)
            return CGPoint(x: x, y: y)

        } else {
            return NSEvent.mouseLocation
        }
    }

    func flagsFrom(modifiers: [String]) -> CGEventFlags {
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod {
            case "command":  flags.insert(.maskCommand)
            case "option":   flags.insert(.maskAlternate)
            case "control":  flags.insert(.maskControl)
            case "shift":    flags.insert(.maskShift)
            default: break
            }
        }
        return flags
    }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

let upgrader = NIOWebSocketServerUpgrader(
    maxFrameSize: 1 << 14,
    automaticErrorHandling: true,
    shouldUpgrade: { _, _ in
        return group.next().makeSucceededFuture([:])
    },
    upgradePipelineHandler: { channel, _ in
        channel.pipeline.addHandler(WebSocketHandler())
    }
)

let bootstrap = ServerBootstrap(group: group)
    .serverChannelOption(ChannelOptions.backlog, value: 256)
    .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline(
            withServerUpgrade: (upgraders: [upgrader], completionHandler: { _ in })
        )
    }
    .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)

defer { try? group.syncShutdownGracefully() }

do {
    let channel = try bootstrap.bind(host: "0.0.0.0", port: 31337).wait()
    print("🟢 Server running at \(channel.localAddress!)")
    try channel.closeFuture.wait()
} catch {
    print("💥 Server crashed: \(error)")
}
