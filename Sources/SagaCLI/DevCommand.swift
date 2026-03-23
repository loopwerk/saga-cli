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
    // Set up SIGUSR2 handler — Saga signals us when a content rebuild completes so we can reload browsers
    signal(SIGUSR2, SIG_IGN)
    let sigusr2Source = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: DispatchQueue(label: "Saga.Signal"))
    sigusr2Source.setEventHandler { [weak self] in self?.server?.sendReload() }
    sigusr2Source.resume()

    // Set up SIGUSR1 handler — Saga signals us when Swift source files change so we can recompile
    signal(SIGUSR1, SIG_IGN)
    let sigusr1Source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: DispatchQueue(label: "Saga.Recompile"))
    sigusr1Source.setEventHandler { [weak self] in self?.recompileAndRelaunch() }
    sigusr1Source.resume()

    // Launch the site process. Saga watches its own files and rebuilds internally.
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

    withExtendedLifetime((sigusr1Source, sigusr2Source, sigintSrc)) {
      dispatchMain()
    }
  }

  func recompileAndRelaunch() {
    log("Source code changed, recompiling...")
    guard swiftBuild() else {
      log("Build failed, waiting for next change...")
      return
    }

    // Build succeeded — kill old process and launch new one
    siteProcess?.terminate()
    siteProcess?.waitUntilExit()

    siteProcess = launchSiteProcess(productName: productName, cachePath: cachePath)
  }
}
