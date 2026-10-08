import Foundation

nonisolated enum StreamEvent: Equatable, Sendable {
    case delta(String)
    /// Full text so far; replaces anything accumulated.
    case snapshot(String)
    case final(String)
    case error(String)
    case done
    case ignore
}

nonisolated enum JSONLine {
    static func object(_ text: some StringProtocol) -> [String: Any]? {
        guard let data = String(text).data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Extracts a human-readable error from common API error shapes.
    static func errorMessage(_ data: Data) -> String? {
        let json = try? JSONSerialization.jsonObject(with: data)
        let object = (json as? [String: Any]) ?? (json as? [[String: Any]])?.first
        return object.flatMap(errorMessage)
    }

    static func errorMessage(_ object: [String: Any]) -> String? {
        if let error = object["error"] as? [String: Any] {
            return (error["message"] as? String) ?? (error["code"] as? String) ?? "Unknown error."
        }
        if let error = object["error"] as? String { return error }
        if let detail = object["detail"] as? String { return detail }
        return nil
    }
}

/// OpenAI-compatible `/chat/completions` server-sent events.
nonisolated enum OpenAIStreamParser {
    static func parse(line: String) -> StreamEvent {
        let line = line.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("data:") else { return .ignore }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return .done }
        guard let object = JSONLine.object(payload) else { return .ignore }
        if let message = JSONLine.errorMessage(object) { return .error(message) }
        return content(object, delta: true)
    }

    /// A non-streaming JSON response body.
    static func parse(body: Data) -> StreamEvent {
        guard let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            return .error("The server sent a result that Lexa cannot read.")
        }
        if let message = JSONLine.errorMessage(object) { return .error(message) }
        return content(object, delta: false)
    }

    private static func content(_ object: [String: Any], delta: Bool) -> StreamEvent {
        guard let choice = (object["choices"] as? [[String: Any]])?.first else { return .ignore }
        if let delta = choice["delta"] as? [String: Any], let text = delta["content"] as? String {
            return text.isEmpty ? .ignore : .delta(text)
        }
        if let message = choice["message"] as? [String: Any], let text = message["content"] as? String {
            return .final(text)
        }
        return .ignore
    }
}

/// `claude -p --output-format stream-json --include-partial-messages`.
nonisolated enum ClaudeStreamParser {
    static func parse(line: String) -> StreamEvent {
        guard let object = JSONLine.object(line), let type = object["type"] as? String else { return .ignore }
        switch type {
        case "stream_event":
            guard let event = object["event"] as? [String: Any],
                  event["type"] as? String == "content_block_delta",
                  let delta = event["delta"] as? [String: Any],
                  delta["type"] as? String == "text_delta",
                  let text = delta["text"] as? String
            else { return .ignore }
            return .delta(text)
        case "assistant":
            let blocks = (object["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
            let text = blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
            return text.isEmpty ? .ignore : .snapshot(text)
        case "result":
            let result = object["result"] as? String ?? ""
            let subtype = object["subtype"] as? String ?? "success"
            if object["is_error"] as? Bool == true || subtype != "success" {
                return .error(result.isEmpty ? subtype : result)
            }
            return .final(result)
        default:
            return .ignore
        }
    }
}

/// `codex exec --json` JSONL events.
nonisolated enum CodexStreamParser {
    static func parse(line: String) -> StreamEvent {
        guard let object = JSONLine.object(line), let type = object["type"] as? String else { return .ignore }
        switch type {
        case "item.completed", "item.updated":
            guard let item = object["item"] as? [String: Any],
                  let itemType = item["type"] as? String,
                  itemType == "agent_message" || itemType == "assistant_message",
                  let text = item["text"] as? String
            else { return .ignore }
            return type == "item.completed" ? .final(text) : .snapshot(text)
        case "turn.failed":
            let message = (object["error"] as? [String: Any])?["message"] as? String
            return .error(message ?? "The Codex task stopped.")
        case "error":
            return .error(object["message"] as? String ?? "Codex sent an error.")
        case "turn.completed":
            return .done
        default:
            return .ignore
        }
    }
}
