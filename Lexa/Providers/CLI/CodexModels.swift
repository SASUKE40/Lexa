import Foundation

/// The Codex CLI keeps the model list for the signed-in account in `$CODEX_HOME/models_cache.json`.
/// The file has only model metadata (no credentials). Lexa uses it to find the newest model.
nonisolated enum CodexModels {
    /// Used when the Codex CLI has not written its model list yet.
    static let fallback = ["gpt-6.1-sol", "gpt-6-astra", "gpt-6-sol", "gpt-6-luna", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"]

    static var cacheURL: URL {
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
        return home.appending(path: "models_cache.json")
    }

    /// Visible models, newest first (the Codex list puts its recommended model at priority 0).
    static func available(cache: URL = cacheURL) -> [String] {
        guard let data = try? Data(contentsOf: cache) else { return fallback }
        let models = parse(data)
        return models.isEmpty ? fallback : models
    }

    static func parse(_ data: Data) -> [String] {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let entries = object["models"] as? [[String: Any]]
        else { return [] }
        return entries
            .filter { ($0["visibility"] as? String ?? "list") == "list" }
            .compactMap { entry -> (slug: String, priority: Int)? in
                guard let slug = entry["slug"] as? String, !slug.isEmpty else { return nil }
                return (slug, entry["priority"] as? Int ?? Int.max)
            }
            .sorted { $0.priority < $1.priority }
            .map(\.slug)
    }
}
