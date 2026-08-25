import Foundation

// Writes the config file a real Saga site would write, tells the CLI the first
// render is done, then stays alive the way Saga does while watching for changes.
// FIXTURE_HANG=1 skips the signal, leaving the CLI parked in its startup wait.

let cwd = FileManager.default.currentDirectoryPath
try? #"{"input":"content","output":"deploy"}"#
  .write(toFile: cwd + "/.build/saga-config.json", atomically: true, encoding: .utf8)

if ProcessInfo.processInfo.environment["FIXTURE_HANG"] == nil {
  kill(getppid(), SIGUSR2)
}

Thread.sleep(forTimeInterval: 600)
