import ArgumentParser
import Foundation

struct Build: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Build the site."
  )

  func run() throws {
    log("Building site...")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "run"]

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
      log("Build complete.")
    } else {
      throw ExitCode(process.terminationStatus)
    }
  }
}
