import Foundation

/// Fetches and caches public model metadata (release dates and per-token USD pricing)
/// from OpenRouter's public `/api/v1/models` catalog.
///
/// Used for:
/// 1. Enriching Google Gemini's `/models` list with release dates (Google omits them).
/// 2. Estimating USD cost when an API provider reports tokens without a `cost` field.
actor ModelCatalog {
    static let shared = ModelCatalog()

    private static let catalogURL = URL(string: "https://openrouter.ai/api/v1/models")!
    private static let ttl: TimeInterval = 60 * 60

    struct ParsedCatalog: Sendable {
        var googleReleaseDates: [String: ModelReleaseDate] = [:]
        var pricingByID: [String: ModelPricing] = [:]
        var pricingByShortName: [String: ModelPricing] = [:]

        var isEmpty: Bool { googleReleaseDates.isEmpty && pricingByID.isEmpty }
    }

    private var cached = ParsedCatalog()
    private var fetchedAt: Date?
    private var inFlight: Task<ParsedCatalog?, Never>?

    func googleReleaseDates() async -> [String: ModelReleaseDate] {
        await catalog().googleReleaseDates
    }

    func pricing(for modelID: String, provider: Provider) async -> ModelPricing? {
        if provider.group == .local { return .free }
        let lower = modelID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower == "openrouter/free" || lower.hasSuffix(":free") { return .free }
        let data = await catalog()
        return Self.lookupPricing(modelID: lower, provider: provider, in: data)
    }

    private func catalog() async -> ParsedCatalog {
        if let fetchedAt, Date().timeIntervalSince(fetchedAt) < Self.ttl, !cached.isEmpty {
            return cached
        }
        if let inFlight { return await inFlight.value ?? cached }

        let task = Task { () -> ParsedCatalog? in
            var request = URLRequest(url: Self.catalogURL, timeoutInterval: 5)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let status = (response as? HTTPURLResponse)?.statusCode,
                  (200..<300).contains(status)
            else {
                return nil
            }
            let parsed = Self.parseOpenRouterCatalog(data)
            return parsed.isEmpty ? nil : parsed
        }
        inFlight = task
        let fresh = await task.value
        inFlight = nil
        if let fresh {
            cached = fresh
            fetchedAt = Date()
        }
        return cached
    }

    nonisolated static func parseOpenRouterCatalog(_ data: Data) -> ParsedCatalog {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let entries = object["data"] as? [[String: Any]]
        else { return ParsedCatalog() }

        var result = ParsedCatalog()
        for entry in entries {
            guard let rawID = entry["id"] as? String, !rawID.isEmpty else { continue }
            let lowerID = rawID.lowercased()
            let baseID = lowerID.split(separator: ":", maxSplits: 1).first.map(String.init) ?? lowerID

            if lowerID.hasPrefix("google/"), let releaseDate = ModelList.releaseDate(of: entry) {
                let modelID = String(lowerID.dropFirst("google/".count))
                recordDate(modelID, date: releaseDate, into: &result.googleReleaseDates)
                if let colon = modelID.firstIndex(of: ":") {
                    recordDate(String(modelID[..<colon]), date: releaseDate, into: &result.googleReleaseDates)
                }
                if let slug = entry["canonical_slug"] as? String, slug.lowercased().hasPrefix("google/") {
                    recordDate(String(slug.lowercased().dropFirst("google/".count)), date: releaseDate, into: &result.googleReleaseDates)
                }
            }

            if let pricing = parsePricing(entry["pricing"]) {
                result.pricingByID[lowerID] = pricing
                if result.pricingByID[baseID] == nil {
                    result.pricingByID[baseID] = pricing
                }
                if let slug = entry["canonical_slug"] as? String, !slug.isEmpty {
                    let lowerSlug = slug.lowercased()
                    if result.pricingByID[lowerSlug] == nil {
                        result.pricingByID[lowerSlug] = pricing
                    }
                }
                if let shortName = baseID.split(separator: "/").last.map(String.init),
                   !shortName.isEmpty,
                   result.pricingByShortName[shortName] == nil {
                    result.pricingByShortName[shortName] = pricing
                }
            }
        }
        return result
    }

    nonisolated static func lookupPricing(
        modelID: String,
        provider: Provider,
        in catalog: ParsedCatalog
    ) -> ModelPricing? {
        let lower = modelID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return nil }
        if lower == "openrouter/free" || lower.hasSuffix(":free") { return .free }

        var candidates = [lower]
        if let match = lower.firstMatch(of: /^(.+)-\d{3}$/) {
            candidates.append(String(match.1))
        }
        for prefix in vendorPrefixes(for: provider) {
            if !lower.contains("/") {
                candidates.append("\(prefix)/\(lower)")
                if let match = lower.firstMatch(of: /^(.+)-\d{3}$/) {
                    candidates.append("\(prefix)/\(match.1)")
                }
            }
        }

        for candidate in candidates {
            if let pricing = catalog.pricingByID[candidate] { return pricing }
        }
        let shortName = lower.split(separator: "/").last.map(String.init) ?? lower
        if let pricing = catalog.pricingByShortName[shortName] { return pricing }
        if let match = shortName.firstMatch(of: /^(.+)-\d{3}$/),
           let pricing = catalog.pricingByShortName[String(match.1)] {
            return pricing
        }
        return nil
    }

    nonisolated private static func vendorPrefixes(for provider: Provider) -> [String] {
        switch provider.id {
        case Provider.gemini.id: ["google"]
        case Provider.mistral.id: ["mistralai"]
        case Provider.nous.id: ["nousresearch"]
        case Provider.codex.id: ["openai"]
        case Provider.claude.id: ["anthropic"]
        case Provider.groq.id, Provider.cerebras.id: ["meta-llama", "qwen", "openai", "deepseek"]
        default: ["openai", "google", "anthropic", "meta-llama", "mistralai"]
        }
    }

    nonisolated private static func parsePricing(_ value: Any?) -> ModelPricing? {
        guard let dict = value as? [String: Any],
              let prompt = parseRate(dict["prompt"]),
              let completion = parseRate(dict["completion"])
        else { return nil }
        let cacheRead = parseRate(dict["input_cache_read"])
        return ModelPricing(promptPerToken: prompt, completionPerToken: completion, cacheReadPerToken: cacheRead)
    }

    nonisolated private static func parseRate(_ value: Any?) -> Double? {
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            let v = number.doubleValue
            return v.isFinite && v >= 0 ? v : nil
        }
        if let string = value as? String, let v = Double(string.trimmingCharacters(in: .whitespaces)),
           v.isFinite, v >= 0 {
            return v
        }
        return nil
    }

    nonisolated private static func recordDate(
        _ id: String,
        date: ModelReleaseDate,
        into dates: inout [String: ModelReleaseDate]
    ) {
        guard !id.isEmpty else { return }
        if let existing = dates[id], existing >= date { return }
        dates[id] = date
    }
}
