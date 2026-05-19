// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Accrue",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Accrue", targets: ["Accrue"]),
    ],
    dependencies: [
        .package(path: "AccrueCore"),
    ],
    targets: [
        .executableTarget(
            name: "Accrue",
            dependencies: [
                .product(name: "AccrueCore", package: "AccrueCore"),
            ],
            path: "Sources/Accrue"
        ),
    ]
)
