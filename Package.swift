// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HealthCards",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        // macOS only so `swift test` runs on CI; the cards are made for iPhone and Apple Watch,
        // and the HealthKit data source is compiled for iOS and watchOS only.
        .macOS(.v14),
    ],
    products: [
        .library(name: "HealthCards", targets: ["HealthCards"]),
        .library(name: "HealthCardsUI", targets: ["HealthCardsUI"]),
    ],
    targets: [
        .target(name: "HealthCards"),
        .target(name: "HealthCardsUI", dependencies: ["HealthCards"]),
        .testTarget(name: "HealthCardsTests", dependencies: ["HealthCards"]),
    ]
)
