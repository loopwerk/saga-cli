// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "saga-cli",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .executable(name: "saga", targets: ["SagaCLI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/loopwerk/SagaPathKit", from: "1.4.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/swhitty/FlyingFox", from: "0.27.0"),
  ],
  targets: [
    .executableTarget(
      name: "SagaCLI",
      dependencies: [
        "SagaPathKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "FlyingFox", package: "FlyingFox"),
        .product(name: "FlyingSocks", package: "FlyingFox"),
      ]
    ),
  ]
)
