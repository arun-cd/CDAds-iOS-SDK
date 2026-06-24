// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CDAds",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "CDAds", targets: ["CDAds"]),
    ],
    targets: [
        .target(
            name: "CDAds",
            path: "Sources/CDAds",
            resources: [
                .process("Internal/MRAID/Resources"),
                .process("Internal/Storage/Resources"),
                .process("Public/Resources"),
            ]
        ),
        .testTarget(
            name: "CDAdsTests",
            dependencies: ["CDAds"],
            path: "Tests/CDAdsTests"
        ),
    ]
)
