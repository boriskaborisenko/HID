// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "hid-transmitter",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "hid-transmitter",
            dependencies: [
                .product(name: "Starscream", package: "Starscream"),
            ]),
        .testTarget(
            name: "hid-transmitterTests",
            dependencies: ["hid-transmitter"]),
    ]
)
