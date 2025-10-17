// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "hid-receiver",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "hid-receiver",
            targets: ["hid-receiver"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "hid-receiver",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
            ],
            // 👇 это важно: указание, что нужен AppKit/CoreGraphics
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit", "-framework", "CoreGraphics"], .when(platforms: [.macOS]))
            ]
        ),
    ]
)
