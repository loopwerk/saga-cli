import ArgumentParser
import Foundation
import SagaPathKit

struct Dev: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Build, watch for changes, and serve the site with auto-reload."
  )

  @Option(name: .shortAndLong, help: "Port for the development server.")
  var port: Int = 3000

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

    let coordinator = DevCoordinator(productName: productName, cachePath: cachePath, port: port)
    try coordinator.start()
  }
}

/// Manages the dev server lifecycle: site process, HTTP server, signal handling.
private final class DevCoordinator: @unchecked Sendable {
  let productName: String
  let cachePath: Path
  let port: Int
  var siteProcess: Process?
  var server: DevServer?

  init(productName: String, cachePath: Path, port: Int) {
    self.productName = productName
    self.cachePath = cachePath
    self.port = port
  }

  func start() throws {
    // Set up SIGUSR2 handler — Saga signals us when a build completes so we can reload browsers
    signal(SIGUSR2, SIG_IGN)
    let sigusr2Source = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: DispatchQueue(label: "Saga.Signal"))
    sigusr2Source.setEventHandler { [weak self] in self?.server?.sendReload() }
    sigusr2Source.resume()

    // Launch the site process. Saga watches its own files and rebuilds internally.
    // Exit code 42 means "Swift source changed, recompile me".
    siteProcess = launchSiteProcess(productName: productName, cachePath: cachePath)
    guard siteProcess != nil else {
      log("Failed to launch site process.")
      throw ExitCode.failure
    }

    // Wait for the initial build to complete (SIGUSR2 or process exit)
    let initialBuild = DispatchSemaphore(value: 0)
    siteProcess?.terminationHandler = { _ in initialBuild.signal() }
    let initialSigusr2 = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: DispatchQueue(label: "Saga.InitialBuild"))
    initialSigusr2.setEventHandler { initialBuild.signal() }
    initialSigusr2.resume()
    initialBuild.wait()
    initialSigusr2.cancel()
    siteProcess?.terminationHandler = nil

    // Read the config file written by Saga to detect output path.
    // If the config file doesn't exist, this is a Saga 2 site which is not supported.
    guard let config = readSagaConfig() else {
      log("This version of saga-cli requires Saga 3.x or later.")
      siteProcess?.terminate()
      throw ExitCode.failure
    }

    // Start the dev server
    let devServer = DevServer(outputPath: config.output, port: port)
    server = devServer

    let serverQueue = DispatchQueue(label: "Saga.DevServer")
    serverQueue.async {
      do {
        try devServer.start()
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

    // Handle Ctrl+C shutdown
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: DispatchQueue(label: "Saga.Signals"))
    sigintSrc.setEventHandler { [weak self] in
      print("\nShutting down...")
      self?.siteProcess?.terminate()
      self?.server?.stop()
      Foundation.exit(0)
    }
    sigintSrc.resume()
    signal(SIGINT, SIG_IGN)

    // Watch for process exits. Exit code 42 = Swift source changed, recompile and relaunch.
    if let process = siteProcess {
      watchProcess(process)
    }

    withExtendedLifetime((sigusr2Source, sigintSrc)) {
      dispatchMain()
    }
  }

  func watchProcess(_ process: Process) {
    process.terminationHandler = { [weak self] terminatedProcess in
      guard let self, terminatedProcess.terminationStatus == 42 else { return }

      log("Source code changed, recompiling...")
      guard swiftBuild() else {
        log("Build failed")
        return
      }

      self.siteProcess = launchSiteProcess(productName: self.productName, cachePath: self.cachePath)
      if let newProcess = self.siteProcess {
        self.watchProcess(newProcess)
      }
    }
  }
}
