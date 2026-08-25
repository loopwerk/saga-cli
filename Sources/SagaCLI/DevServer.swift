import FlyingFox
import FlyingSocks
import Foundation

final class DevServer: @unchecked Sendable {
  private let server: HTTPServer
  private let sseConnections = SSEConnectionStore()
  private var task: Task<Void, Never>?

  init(outputPath: String, port: Int) throws {
    let root = FileManager.default.currentDirectoryPath + "/" + outputPath
    server = try HTTPServer(
      address: .inet(ip4: "127.0.0.1", port: UInt16(port)),
      handler: RequestHandler(outputPath: root, sseConnections: sseConnections)
    )
  }

  /// Returns once the server is accepting connections, so the caller can print
  /// its address and open a browser without racing the bind.
  func start() throws {
    let listening = DispatchSemaphore(value: 0)
    let outcome = Locked(initialState: Error?.none)

    task = Task { [server] in
      do {
        try await server.run()
      } catch {
        outcome.withLock { $0 = error }
        listening.signal()
      }
    }

    Task { [server] in
      do {
        try await server.waitUntilListening()
      } catch {
        outcome.withLock { $0 = error }
      }
      listening.signal()
    }

    listening.wait()
    if let error = outcome.withLock({ $0 }) {
      throw error
    }
  }

  func stop() {
    task?.cancel()
  }

  func sendReload() {
    sseConnections.sendReload()
  }
}

/// Open `/_reload` streams. Reloads are broadcast from a signal handler, so
/// `sendReload` has to be callable from outside the server's tasks.
final class SSEConnectionStore: @unchecked Sendable {
  private let connections = Locked(initialState: [UUID: AsyncStream<[UInt8]>.Continuation]())

  func add(_ continuation: AsyncStream<[UInt8]>.Continuation, id: UUID) {
    connections.withLock { $0[id] = continuation }
  }

  func remove(id: UUID) {
    connections.withLock { $0[id] = nil }
  }

  func sendReload() {
    let current = connections.withLock { Array($0.values) }
    for continuation in current {
      continuation.yield(Array("data: reload\n\n".utf8))
    }
  }
}

private struct RequestHandler: HTTPHandler {
  let outputPath: String
  let sseConnections: SSEConnectionStore

  func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    if request.path == "/_reload" {
      return sseResponse()
    }

    guard let filePath = resolveFilePath(uri: request.path),
          let data = FileManager.default.contents(atPath: filePath)
    else {
      return HTTPResponse(
        statusCode: .notFound,
        headers: [.contentType: "text/plain"],
        body: Data("404 Not Found".utf8)
      )
    }

    let contentType = mimeType(for: filePath)
    var body = data
    if contentType == "text/html", let html = String(data: data, encoding: .utf8) {
      body = Data(injectReloadScript(into: html).utf8)
    }

    return HTTPResponse(
      statusCode: .ok,
      headers: [.contentType: contentType, .cacheControl: "no-cache"],
      body: body
    )
  }

  private func sseResponse() -> HTTPResponse {
    let id = UUID()
    let (stream, continuation) = AsyncStream<[UInt8]>.makeStream()
    let connections = sseConnections
    continuation.onTermination = { _ in connections.remove(id: id) }
    connections.add(continuation, id: id)

    // No Content-Length, so the body is chunked and the connection stays open.
    return HTTPResponse(
      statusCode: .ok,
      headers: [.contentType: "text/event-stream", .cacheControl: "no-cache"],
      body: HTTPBodySequence(from: SSEBody(stream: stream))
    )
  }

  private func resolveFilePath(uri: String) -> String? {
    let path = uri.split(separator: "?").first.map(String.init) ?? uri
    let fileManager = FileManager.default

    // Direct file match
    let directPath = outputPath + path
    var isDir: ObjCBool = false
    if fileManager.fileExists(atPath: directPath, isDirectory: &isDir) {
      if !isDir.boolValue {
        return directPath
      }
      // It's a directory, look for index.html
      let indexPath = directPath.hasSuffix("/") ? directPath + "index.html" : directPath + "/index.html"
      if fileManager.fileExists(atPath: indexPath) {
        return indexPath
      }
    }

    // Try with .html extension
    let htmlPath = directPath + ".html"
    if fileManager.fileExists(atPath: htmlPath) {
      return htmlPath
    }

    // Try path/index.html
    let indexPath = directPath.hasSuffix("/") ? directPath + "index.html" : directPath + "/index.html"
    if fileManager.fileExists(atPath: indexPath) {
      return indexPath
    }

    return nil
  }

  private func injectReloadScript(into html: String) -> String {
    let script = """
    <script>new EventSource('/_reload').onmessage=function(){location.reload()}</script>
    """
    if let range = html.range(of: "</body>", options: .backwards) {
      return html.replacingCharacters(in: range, with: script + "</body>")
    }
    return html + script
  }

  private func mimeType(for path: String) -> String {
    let ext = if let dotIndex = path.lastIndex(of: ".") {
      String(path[path.index(after: dotIndex)...]).lowercased()
    } else {
      ""
    }
    switch ext {
      case "html", "htm": return "text/html"
      case "css": return "text/css"
      case "js": return "application/javascript"
      case "json": return "application/json"
      case "xml": return "application/xml"
      case "png": return "image/png"
      case "jpg", "jpeg": return "image/jpeg"
      case "gif": return "image/gif"
      case "svg": return "image/svg+xml"
      case "webp": return "image/webp"
      case "ico": return "image/x-icon"
      case "woff": return "font/woff"
      case "woff2": return "font/woff2"
      case "ttf": return "font/ttf"
      case "otf": return "font/otf"
      case "pdf": return "application/pdf"
      case "txt": return "text/plain"
      default: return "application/octet-stream"
    }
  }
}

/// Adapts an `AsyncStream` of byte chunks to the buffered sequence FlyingFox
/// streams response bodies from. The concrete adapters it ships are
/// package-internal, so this fills that gap.
private struct SSEBody: AsyncBufferedSequence {
  typealias Element = UInt8

  let stream: AsyncStream<[UInt8]>

  func makeAsyncIterator() -> Iterator {
    Iterator(inner: stream.makeAsyncIterator())
  }

  struct Iterator: AsyncBufferedIteratorProtocol {
    var inner: AsyncStream<[UInt8]>.Iterator
    private var pending: [UInt8] = []

    init(inner: AsyncStream<[UInt8]>.Iterator) {
      self.inner = inner
    }

    mutating func nextBuffer(suggested count: Int) async throws -> [UInt8]? {
      if !pending.isEmpty {
        let buffer = pending
        pending = []
        return buffer
      }
      return await inner.next()
    }

    mutating func next() async throws -> UInt8? {
      if pending.isEmpty {
        guard let chunk = await inner.next() else { return nil }
        pending = chunk
      }
      return pending.isEmpty ? nil : pending.removeFirst()
    }
  }
}
