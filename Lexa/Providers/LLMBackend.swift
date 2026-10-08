import Foundation

nonisolated struct LLMRequest: Sendable, Equatable {
    var system: String
    var user: String
    var temperature: Double
    var model: String
}

nonisolated enum TextUpdate: Sendable, Equatable {
    case append(String)
    case replace(String)
}

nonisolated enum BackendStatus: Sendable, Equatable {
    case ready(String)
    case problem(String)
}

nonisolated struct LLMError: LocalizedError, Sendable, Equatable {
    let message: String

    init(_ message: String) { self.message = message }

    var errorDescription: String? { message }
}

nonisolated protocol LLMBackend: Sendable {
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<TextUpdate, Error>
    /// Verifies credentials / reachability for the Settings "Test" button.
    func test() async -> BackendStatus
    func listModels() async throws -> [String]
}

nonisolated extension LLMBackend {
    /// Sends a tiny real request; returns how long the round trip took.
    func ping(model: String) async throws -> String {
        let clock = ContinuousClock()
        let start = clock.now
        var reply = ""
        let request = LLMRequest(system: "Reply with the single word OK.", user: "Ping", temperature: 0, model: model)
        for try await update in stream(request) {
            switch update {
            case .append(let text): reply += text
            case .replace(let text): reply = text
            }
        }
        if ResponseCleaner.stripThinking(reply).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMError("The connection is good, but the model sent an empty result.")
        }
        let elapsed = clock.now - start
        return elapsed.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))
    }

    /// Runs `body` in a task whose lifetime is tied to the returned stream.
    static func makeStream(
        _ body: @escaping @Sendable (AsyncThrowingStream<TextUpdate, Error>.Continuation) async throws -> Void
    ) -> AsyncThrowingStream<TextUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await body(continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
