import Foundation
import Network

/// One-shot HTTP listener on the loopback interface that receives an OAuth redirect.
nonisolated final class LoopbackServer: @unchecked Sendable {
    let path: String
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.sasuke40.lexa.oauth-loopback")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[String: String], Error>?
    private var result: Result<[String: String], Error>?

    init(path: String = "/callback") throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        listener = try NWListener(using: parameters, on: .any)
        self.path = path
    }

    /// Starts listening and returns the port the OS picked.
    func start() async throws -> UInt16 {
        let started = OnceFlag()
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if started.claim() { continuation.resume(returning: self?.listener.port?.rawValue ?? 0) }
                case .failed(let error):
                    if started.claim() { continuation.resume(throwing: error) } else { self?.finish(.failure(error)) }
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
            listener.start(queue: queue)
        }
    }

    /// Waits for the first request to `path` and returns its query items.
    func waitForCallback(timeout: Duration) async throws -> [String: String] {
        let timer = Task { [weak self] in
            try await Task.sleep(for: timeout)
            self?.finish(.failure(LLMError("The sign-in did not complete in \(timeout.components.seconds / 60) minutes. Try again.")))
        }
        defer { timer.cancel() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let ready: Result<[String: String], Error>? = lock.withLock {
                    if result == nil { self.continuation = continuation }
                    return result
                }
                if let ready { continuation.resume(with: ready) }
            }
        } onCancel: {
            finish(.failure(CancellationError()))
        }
    }

    func stop() {
        listener.cancel()
    }

    /// Parses `GET /callback?code=…&state=… HTTP/1.1` into query items, or nil for other requests.
    static func query(fromRequest request: String, path: String) -> [String: String]? {
        guard let line = request.components(separatedBy: "\r\n").first else { return nil }
        let parts = line.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET",
              let components = URLComponents(string: "http://localhost" + parts[1]),
              components.path == path
        else { return nil }
        let items = (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        return Dictionary(items, uniquingKeysWith: { first, _ in first })
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self else { return }
            let request = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
            if let query = Self.query(fromRequest: request, path: path) {
                respond(connection, status: "200 OK", body: Self.page)
                finish(.success(query))
            } else {
                respond(connection, status: "404 Not Found", body: "")
            }
        }
    }

    private func respond(_ connection: NWConnection, status: String, body: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

    private func finish(_ outcome: Result<[String: String], Error>) {
        let waiting: CheckedContinuation<[String: String], Error>? = lock.withLock {
            guard result == nil else { return nil }
            result = outcome
            defer { continuation = nil }
            return continuation
        }
        waiting?.resume(with: outcome)
    }

    private static let page = """
        <!doctype html><html><head><meta charset="utf-8"><title>Lexa</title>
        <style>body{font:16px -apple-system,sans-serif;display:grid;place-items:center;height:90vh;color:#333}</style>
        </head><body><div><h2>Lexa</h2><p>The sign-in is complete. You can close this window.</p></div></body></html>
        """
}

private nonisolated final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.withLock {
            defer { claimed = true }
            return !claimed
        }
    }
}
