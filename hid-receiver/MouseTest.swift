import Foundation
import CoreGraphics

print("🧪 Moving mouse...")

let loc = CGPoint(x: 300, y: 300)
let e = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: loc, mouseButton: .left)
e?.post(tap: .cghidEventTap)

print("✅ Done")

