// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "vite",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "vite",
            dependencies: []
        ),
        .testTarget(
            name: "viteTests",
            dependencies: ["vite"]
        )
    ]
)
