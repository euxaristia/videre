// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "videre",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "videre",
            dependencies: []
        ),
        .testTarget(
            name: "videreTests",
            dependencies: ["videre"]
        )
    ]
)
