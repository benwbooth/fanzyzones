// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "FanzyZones",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "FanzyZones",
            path: "Sources/FanzyZones"
        ),
        .testTarget(
            name: "FanzyZonesTests",
            dependencies: ["FanzyZones"],
            path: "Tests/FanzyZonesTests"
        )
    ]
)
