import Foundation

nonisolated struct OpenAICompatibleBackend: LLMBackend {
    let provider: Provider
    let baseURL: String
    let apiKey: String
    let model: String

    static func endpoint(_ baseURL: String, _ path: String) -> URL? {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard !base.isEmpty else { return nil }
        return URL(string: base + "/" + path)
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<TextUpdate, Error> {
        Self.makeStream { continuation in
            let urlRequest = try makeChatRequest(request, stream: true)
            let (bytes, response) = try await perform { try await URLSession.shared.bytes(for: urlRequest) }
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0

            guard (200..<300).contains(status) else {
                var body = Data()
                for try await byte in bytes {
                    body.append(byte)
                    if body.count > 32_768 { break }
                }
                throw httpError(status: status, body: body, model: request.model)
            }

            let contentType = http?.value(forHTTPHeaderField: "Content-Type") ?? ""
            if contentType.contains("text/event-stream") {
                lines: for try await line in bytes.lines {
                    switch OpenAIStreamParser.parse(line: line) {
                    case .delta(let text): continuation.yield(.append(text))
                    case .snapshot(let text), .final(let text): continuation.yield(.replace(text))
                    case .error(let message): throw LLMError(message)
                    case .done: break lines
                    case .ignore: continue
                    }
                }
            } else {
                var body = Data()
                for try await byte in bytes { body.append(byte) }
                switch OpenAIStreamParser.parse(body: body) {
                case .final(let text), .snapshot(let text), .delta(let text): continuation.yield(.replace(text))
                case .error(let message): throw LLMError(message)
                case .done, .ignore: throw LLMError("The model returned an empty response.")
                }
            }
        }
    }

    func test() async -> BackendStatus {
        if provider.needsKey, apiKey.isEmpty { return .problem("Add an API key first.") }
        do {
            let elapsed = try await ping(model: model)
            return .ready("\(model) replied in \(elapsed)")
        } catch {
            return .problem(error.localizedDescription)
        }
    }

    func listModels() async throws -> [String] {
        guard let url = Self.endpoint(baseURL, "models") else { throw LLMError("Set a base URL first.") }
        var request = URLRequest(url: url, timeoutInterval: 20)
        applyHeaders(&request)
        let (data, response) = try await perform { try await URLSession.shared.data(for: request) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw httpError(status: status, body: data, model: "") }

        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let entries = (object?["data"] as? [[String: Any]]) ?? (object?["models"] as? [[String: Any]]) ?? []
        var ids = entries.compactMap { ($0["id"] as? String) ?? ($0["name"] as? String) }
        ids = ids.map { $0.hasPrefix("models/") ? String($0.dropFirst(7)) : $0 }
        if provider.id == Provider.openRouter.id {
            ids = ["openrouter/free"] + ids.filter { $0.hasSuffix(":free") }.sorted()
        } else {
            ids.sort()
        }
        return ids
    }

    // MARK: - Helpers

    private func makeChatRequest(_ request: LLMRequest, stream: Bool) throws -> URLRequest {
        guard let url = Self.endpoint(baseURL, "chat/completions") else { throw LLMError("Set a base URL for \(provider.name).") }
        guard !request.model.isEmpty else { throw LLMError("Choose a model for \(provider.name) in Settings.") }
        if provider.needsKey, apiKey.isEmpty { throw LLMError("Add your \(provider.name) API key in Settings.") }

        var urlRequest = URLRequest(url: url, timeoutInterval: 120)
        urlRequest.httpMethod = "POST"
        applyHeaders(&urlRequest)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": request.model,
            "stream": stream,
            "temperature": request.temperature,
            "messages": [
                ["role": "system", "content": request.system],
                ["role": "user", "content": request.user],
            ],
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    private func applyHeaders(_ request: inout URLRequest) {
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        for (name, value) in provider.extraHeaders { request.setValue(value, forHTTPHeaderField: name) }
    }

    private func perform<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                throw LLMError(provider.group == .local
                    ? "Couldn't connect to \(baseURL). Is \(provider.name) running?"
                    : "Couldn't reach \(provider.name).")
            case .notConnectedToInternet: throw LLMError("You're offline.")
            case .timedOut: throw LLMError("\(provider.name) took too long to respond.")
            default: throw LLMError(error.localizedDescription)
            }
        }
    }

    private func httpError(status: Int, body: Data, model: String) -> LLMError {
        let detail = JSONLine.errorMessage(body)
            ?? String(data: body.prefix(300), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let suffix = detail.isEmpty ? "" : " (\(detail))"
        switch status {
        case 401, 403: return LLMError("\(provider.name) rejected the API key\(suffix).")
        case 402: return LLMError("Out of credits on \(provider.name). Pick a free model\(suffix).")
        case 404: return LLMError("Model \"\(model)\" wasn't found on \(provider.name)\(suffix).")
        case 429: return LLMError("Rate limited by \(provider.name). Free tiers have limits; try again shortly or switch model\(suffix).")
        default: return LLMError("\(provider.name) returned HTTP \(status)\(suffix).")
        }
    }
}
