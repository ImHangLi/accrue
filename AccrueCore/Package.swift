// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AccrueCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AccrueCore", targets: ["AccrueCore"]),
    ],
    targets: [
        .target(name: "AccrueCore"),
        .testTarget(
            name: "AccrueCoreTests",
            dependencies: ["AccrueCore"]
        ),
    ]
)
