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
        .package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.13.0"),
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
                .product(name: "TelemetryDeck", package: "SwiftSDK"),
                "AccrueAppSupport",
            ],
            path: "Sources/Accrue",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "AccrueAppSupportTests",
            dependencies: ["AccrueAppSupport"],
            path: "Tests/AccrueAppSupportTests"
        ),
    ]
)
