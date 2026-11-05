// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrivacyDragAndDrop",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PrivacyDragAndDrop", targets: ["PrivacyDragAndDrop"]),
    ],
    targets: [
        .target(name: "PrivacyDragAndDrop"),
        .executableTarget(name: "PrivacyDragAndDropDemo", dependencies: ["PrivacyDragAndDrop"]),
    ]
)
