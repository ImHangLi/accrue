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
        .target(
            name: "AccrueAppSupport",
            dependencies: [
                .product(name: "AccrueCore", package: "AccrueCore"),
            ],
            path: "Sources/AccrueAppSupport"
        ),
        .executableTarget(
            name: "Accrue",
            dependencies: [
                .product(name: "AccrueCore", package: "AccrueCore"),
                "AccrueAppSupport",
            ],
            path: "Sources/Accrue"
        ),
        .testTarget(
            name: "AccrueAppSupportTests",
            dependencies: ["AccrueAppSupport"],
            path: "Tests/AccrueAppSupportTests"
        ),
    ]
)
