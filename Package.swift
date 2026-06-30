// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CDCSimulator",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CDCSimulator", targets: ["CDCSimulator"]),
        .executable(name: "cdc-server", targets: ["cdc-server"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swhitty/FlyingFox.git", from: "0.26.0"),
    ],
    targets: [
        .target(
            name: "CDCSimulatorCore",
            dependencies: [
                .product(name: "FlyingFox", package: "FlyingFox"),
            ],
            path: "Sources/CDCSimulatorCore"
        ),
        .executableTarget(
            name: "CDCSimulator",
            dependencies: ["CDCSimulatorCore"],
            path: "Sources/CDCSimulator"
        ),
        .executableTarget(
            name: "cdc-server",
            dependencies: ["CDCSimulatorCore"],
            path: "Sources/cdc-server"
        ),
    ]
)