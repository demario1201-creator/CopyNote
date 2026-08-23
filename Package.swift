// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CopyNote",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "CopyNote", path: "Sources/CopyNote")
    ]
)
