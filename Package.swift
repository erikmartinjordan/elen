// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "elen",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "elen",
            path: "Sources/elen"
        )
    ]
)
