import ArgumentParser
import Foundation
import SagaPathKit

struct Dev: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Build, watch for changes, and serve the site with auto-reload."
  )

  @Option(name: .shortAndLong, help: "Folder to watch for changes. Can be specified multiple times.")
  var watch: [String] = ["content", "Sources"]

  @Option(name: .shortAndLong, help: "Output folder for the built site.")
  var output: String = "deploy"

  @Option(name: .shortAndLong, help: "Port for the development server.")
  var port: Int = 3000

  @Option(name: .shortAndLong, help: "Glob pattern for files to ignore. Can be specified multiple times.")
  var ignore: [String] = []

  func run() throws {
    // Create a fresh cache directory for this dev session
    let cachePath = Path.current + ".build/saga-cache"
    if cachePath.exists {
      try cachePath.delete()
    }
    try cachePath.mkpath()

    // Find the executable product name from Package.swift
    guard let productName = findExecutableProduct() else {
      print("Could not find an executable product in Package.swift")
      throw ExitCode.failure
    }

    // Initial build
    log("Building site...")
    guard swiftBuild() else {
      log("Initial build failed.")
      throw ExitCode.failure
    }

    // Set up SIGUSR2 handler — the site process signals us when a build completes
    let buildComplete = DispatchSemaphore(value: 0)
    signal(SIGUSR2, SIG_IGN)
    let sigusr2Source = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: DispatchQueue(label: "Saga.Signal"))
    sigusr2Source.setEventHandler { buildComplete.signal() }
    sigusr2Source.resume()

    // Launch the site process (stays alive, waiting for SIGUSR1 between rebuilds)
    var siteProcess = launchSiteProcess(productName: productName, cachePath: cachePath)
    if let siteProcess {
      // Wait for the initial build to finish
      buildComplete.wait()
      guard siteProcess.isRunning else {
        log("Initial build failed.")
        throw ExitCode.failure
      }
    } else {
      log("Failed to launch site process, starting server anyway...")
    }

    // Start the dev server
    let server = DevServer(outputPath: output, port: port)

    let serverQueue = DispatchQueue(label: "Saga.DevServer")
    serverQueue.async {
      do {
        try server.start()
      } catch {
        print("Failed to start server: \(error)")
        Foundation.exit(1)
      }
    }

    // Give the server a moment to start
    Thread.sleep(forTimeInterval: 0.5)
    log("Development server running at http://localhost:\(port)/")

    // Open the browser
    openBrowser(url: "http://localhost:\(port)/")

    // Turn watch folders into full paths
    let currentPath = FileManager.default.currentDirectoryPath
    let paths = watch.map { folder -> String in
      if folder.hasPrefix("/") {
        return folder
      }
      return currentPath + "/" + folder
    }

    let defaultIgnorePatterns = [".DS_Store"]

    // Start monitoring
    if !ignore.isEmpty {
      log("Ignoring patterns: \(ignore.joined(separator: ", "))")
    }

    var isRebuilding = false
    let rebuildLock = NSLock()

    let folderMonitor = FolderMonitor(paths: paths, ignoredPatterns: defaultIgnorePatterns + ignore) { changedPaths in
      rebuildLock.lock()
      guard !isRebuilding else {
        rebuildLock.unlock()
        return
      }
      isRebuilding = true
      rebuildLock.unlock()

      if changedPaths.contains(where: { $0.hasSuffix(".swift") }) {
        // Swift code changed: kill the process, recompile, relaunch
        log("Source code changed, recompiling...")
        siteProcess?.terminate()
        siteProcess?.waitUntilExit()

        guard swiftBuild() else {
          log("Build failed")
          rebuildLock.lock()
          isRebuilding = false
          rebuildLock.unlock()
          return
        }

        siteProcess = launchSiteProcess(productName: productName, cachePath: cachePath)
      } else {
        // Content changed: signal the running process to rebuild
        log("Change detected, rebuilding...")
        if let process = siteProcess, process.isRunning {
          kill(process.processIdentifier, SIGUSR1)
        } else {
          // Process died, relaunch
          siteProcess = launchSiteProcess(productName: productName, cachePath: cachePath)
        }
      }

      // Wait for the site process to signal build completion
      buildComplete.wait()

      if let process = siteProcess, process.isRunning {
        server.sendReload()
      } else {
        log("Rebuild failed")
      }

      rebuildLock.lock()
      isRebuilding = false
      rebuildLock.unlock()
    }

    // Handle Ctrl+C shutdown
    let signalsQueue = DispatchQueue(label: "Saga.Signals")
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalsQueue)
    sigintSrc.setEventHandler {
      print("\nShutting down...")
      siteProcess?.terminate()
      server.stop()
      Foundation.exit(0)
    }
    sigintSrc.resume()
    signal(SIGINT, SIG_IGN)

    log("Watching for changes in: \(watch.joined(separator: ", "))")

    // Prevent folderMonitor from being deallocated
    withExtendedLifetime(folderMonitor) {
      // Keep running
      dispatchMain()
    }
  }
}
