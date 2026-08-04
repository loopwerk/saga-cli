import Foundation
import SagaPathKit

struct SagaConfig: Codable {
  let input: String
  let output: String
}

/// Read the config file written by Saga at `.build/saga-config.json`.
func readSagaConfig() -> SagaConfig? {
  let configPath = Path.current + ".build/saga-config.json"
  guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath.string)) else {
    return nil
  }
  return try? JSONDecoder().decode(SagaConfig.self, from: data)
}

private let logDateFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "yyyy-MM-dd HH:mm:ss"
  return f
}()

func log(_ message: String) {
  print("\(logDateFormatter.string(from: Date())) | \(message)")
}

/// Find the first executable product name using `swift package dump-package`.
func findExecutableProduct() -> String? {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = ["swift", "package", "dump-package"]
  process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = FileHandle.nullDevice

  do {
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let products = json["products"] as? [[String: Any]]
    else { return nil }

    // Find the first executable product
    for product in products {
      if let type = product["type"] as? [String: Any],
         type["executable"] != nil,
         let name = product["name"] as? String
      {
        return name
      }
    }

    // Fall back to the first executable target (packages without explicit products)
    if let targets = json["targets"] as? [[String: Any]] {
      for target in targets {
        if let type = target["type"] as? String,
           type == "executable",
           let name = target["name"] as? String
        {
          return name
        }
      }
    }

    return nil
  } catch {
    return nil
  }
}

/// Runs `swift build`. `onStart` receives the process, so callers can interrupt it.
func swiftBuild(onStart: ((Process) -> Void)? = nil) -> Bool {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = ["swift", "build"]
  process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  process.environment = ProcessInfo.processInfo.environment

  do {
    try process.run()
    onStart?(process)
    process.waitUntilExit()
    return process.terminationStatus == 0
  } catch {
    print("Build error: \(error)")
    return false
  }
}

/// Terminates `process`, escalating to SIGKILL after `timeout`. Shutdown runs with
/// SIGINT ignored, so waiting forever on a child that blocks SIGTERM would leave the
/// CLI unkillable from its own terminal.
func terminate(_ process: Process?, timeout: TimeInterval = 5) {
  guard let process, process.isRunning else { return }
  process.terminate()

  let deadline = Date().addingTimeInterval(timeout)
  while process.isRunning, Date() < deadline {
    Thread.sleep(forTimeInterval: 0.01)
  }

  if process.isRunning {
    kill(process.processIdentifier, SIGKILL)
    process.waitUntilExit()
  }
}

func launchSiteProcess(productName: String, cachePath: Path) -> Process? {
  let binPath = FileManager.default.currentDirectoryPath + "/.build/debug/\(productName)"

  let process = Process()
  process.executableURL = URL(fileURLWithPath: binPath)
  process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  var env = ProcessInfo.processInfo.environment
  env["SAGA_DEV"] = "1"
  env["SAGA_CLI"] = "2"
  env["SAGA_CACHE_DIR"] = cachePath.string
  process.environment = env

  do {
    try process.run()
    return process
  } catch {
    print("Launch error: \(error)")
    return nil
  }
}

func openBrowser(url: String) {
  #if os(macOS)
    Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [url])
  #elseif os(Linux)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["xdg-open", url]
    try? process.run()
  #endif
}
