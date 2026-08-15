// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ChengyinCompanion",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ChengyinCompanion", targets: ["CompanionApp"]),
        .library(name: "CompanionContracts", targets: ["CompanionContracts"]),
        .executable(name: "CompanionContractChecks", targets: ["CompanionContractChecks"]),
        .executable(name: "CompanionEventEmitter", targets: ["CompanionEventEmitter"])
    ],
    targets: [
        .target(
            name: "CompanionContracts",
            path: "Sources/CompanionContracts"
        ),
        .executableTarget(
            name: "CompanionApp",
            dependencies: ["CompanionContracts"],
            path: "Sources/CompanionApp",
            resources: [.process("Resources")],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-concurrency"], .when(configuration: .debug))
            ]
        ),
        .executableTarget(
            name: "CompanionContractChecks",
            dependencies: ["CompanionContracts"],
            path: "Tests/CompanionContractsTests"
        ),
        .executableTarget(
            name: "CompanionEventEmitter",
            dependencies: ["CompanionContracts"],
            path: "Tools/CompanionEventEmitter"
        )
    ]
)
