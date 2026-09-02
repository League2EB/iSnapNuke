// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iSnapNuke",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "iSnapNukeCore", targets: ["iSnapNukeCore"]),
        .executable(name: "iSnapNuke", targets: ["iSnapNukeApp"]),
        .executable(name: "iSnapNukeReleaseTool", targets: ["iSnapNukeReleaseTool"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/simibac/ConfettiSwiftUI.git",
            from: "3.0.0"
        ),
        .package(
            url: "https://github.com/sparkle-project/Sparkle.git",
            exact: "2.9.6"
        ),
    ],
    targets: [
        .target(
            name: "iSnapNukeLocalization",
            path: "Sources/iSnapNukeLocalization",
            resources: [.process("Resources")]
        ),
        .target(
            name: "iSnapNukeCore",
            dependencies: ["iSnapNukeLocalization"],
            path: "Sources/iSnapNukeCore"
        ),
        .executableTarget(
            name: "iSnapNukeApp",
            dependencies: [
                "iSnapNukeCore",
                "iSnapNukeLocalization",
                .product(name: "ConfettiSwiftUI", package: "ConfettiSwiftUI"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/iSnapNukeApp"
        ),
        .executableTarget(
            name: "iSnapNukeReleaseTool",
            dependencies: ["iSnapNukeCore"],
            path: "Sources/iSnapNukeReleaseTool"
        ),
        .testTarget(
            name: "iSnapNukeCoreTests",
            dependencies: ["iSnapNukeCore", "iSnapNukeLocalization"],
            path: "Tests/iSnapNukeCoreTests",
            resources: [.process("Fixtures")]
        ),
    ]
)
