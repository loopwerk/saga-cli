// swift-tools-version:6.0
import PackageDescription

// Stands in for a Saga site so the shutdown tests don't need the real Saga
// dependency graph. Built and driven by ../run-shutdown-tests.sh.
let package = Package(
  name: "fixture",
  products: [.executable(name: "Fixture", targets: ["Fixture"])],
  targets: [.executableTarget(name: "Fixture", path: "Sources/Fixture")]
)
