// swift-tools-version:5.10

import PackageDescription

let package = Package(
  name: "saga-cli",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .executable(name: "saga", targets: ["SagaCLI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kylef/PathKit", from: "1.0.1"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/apple/swift-nio", from: "2.65.0"),
  ],
  targets: [
    .executableTarget(
      name: "SagaCLI",
      dependencies: [
        "PathKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
      ]
    ),
  ]
)
