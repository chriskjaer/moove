// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "moove",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Moove", targets: ["Moove"])],
    targets: [
        .target(name: "WindowGeometry"),
        .target(name: "MooveShortcuts", dependencies: ["WindowGeometry"]),
        .executableTarget(name: "Moove", dependencies: ["WindowGeometry", "MooveShortcuts"]),
        .executableTarget(name: "ShortcutChecks", dependencies: ["MooveShortcuts"], path: "Tests/ShortcutChecks"),
        .executableTarget(name: "GeometryChecks", dependencies: ["WindowGeometry"], path: "Tests/GeometryChecks")
    ]
)
