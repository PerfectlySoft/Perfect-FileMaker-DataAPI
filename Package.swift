// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PerfectFileMakerDataAPI",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "PerfectFileMakerDataAPI", targets: ["PerfectFileMakerDataAPI"]),
    ],
    targets: [
        .target(name: "PerfectFileMakerDataAPI"),
        .testTarget(name: "PerfectFileMakerDataAPITests", dependencies: ["PerfectFileMakerDataAPI"]),
    ]
)
