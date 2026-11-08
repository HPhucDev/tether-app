// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TetherCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "TetherCore", targets: ["TetherCore"]),
    ],
    targets: [
        .target(name: "TetherCore"),
        .testTarget(name: "TetherCoreTests", dependencies: ["TetherCore"]),
    ]
)
