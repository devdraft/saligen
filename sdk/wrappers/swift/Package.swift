// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "YourAPI",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "YourAPI",
            targets: ["YourAPI"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "YourAPI",
            dependencies: []),
        .testTarget(
            name: "YourAPITests",
            dependencies: ["YourAPI"]),
    ]
)

