import Foundation
import Observation

/// Token counts and optional USD cost for a single LLM request.
nonisolated struct TokenUsage: Hashable, Codable, Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var cachedInputTokens: Int
    var costUSD: Double?

    init(inputTokens: Int = 0, outputTokens: Int = 0, cachedInputTokens: Int = 0, costUSD: Double? = nil) {
        self.inputTokens = max(inputTokens, 0)
        self.outputTokens = max(outputTokens, 0)
        self.cachedInputTokens = min(max(cachedInputTokens, 0), max(inputTokens, 0))
        self.costUSD = costUSD.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }

    var totalTokens: Int { inputTokens + outputTokens }
    var isEmpty: Bool { totalTokens == 0 && costUSD == nil }

    func withEstimatedCost(_ pricing: ModelPricing?) -> TokenUsage {
        guard costUSD == nil, let pricing else { return self }
        var copy = self
        copy.costUSD = pricing.cost(for: self)
        return copy
    }

    var detailTooltip: String {
        var parts = ["Input: \(inputTokens.formatted()) tokens", "Output: \(outputTokens.formatted()) tokens"]
        if cachedInputTokens > 0 {
            parts.append("Cached: \(cachedInputTokens.formatted()) tokens")
        }
        if let costUSD {
            parts.append("Cost: \(UsageFormatting.cost(costUSD))")
        }
        return parts.joined(separator: " · ")
    }
}

/// Per-token USD pricing for a model.
nonisolated struct ModelPricing: Hashable, Sendable {
    let promptPerToken: Double
    let completionPerToken: Double
    let cacheReadPerToken: Double?

    static let free = ModelPricing(promptPerToken: 0, completionPerToken: 0, cacheReadPerToken: 0)

    func cost(for usage: TokenUsage) -> Double {
        let cached = usage.cachedInputTokens
        let uncached = max(usage.inputTokens - cached, 0)
        let cacheRate = cacheReadPerToken ?? promptPerToken
        let total = Double(uncached) * promptPerToken
            + Double(cached) * cacheRate
            + Double(usage.outputTokens) * completionPerToken
        return max(total, 0)
    }
}

/// Extracts token and cost metrics from OpenAI-compatible, Claude Code, and Codex JSON payloads.
nonisolated enum UsageParser {
    static func parse(_ object: [String: Any]) -> TokenUsage? {
        let usageObject = (object["usage"] as? [String: Any])
            ?? ((object["x_groq"] as? [String: Any])?["usage"] as? [String: Any])
        let topCost = doubleValue(object["total_cost_usd"]) ?? doubleValue(object["cost"])
        guard usageObject != nil || topCost != nil else { return nil }

        let usage = usageObject ?? [:]
        let output = intValue(usage["completion_tokens"]) ?? intValue(usage["output_tokens"]) ?? 0

        let promptDetails = (usage["prompt_tokens_details"] as? [String: Any])
            ?? (usage["input_tokens_details"] as? [String: Any])
        let cachedRead = intValue(usage["cache_read_input_tokens"])
            ?? intValue(usage["cached_input_tokens"])
            ?? intValue(promptDetails?["cached_tokens"])
            ?? 0
        let cacheCreation = intValue(usage["cache_creation_input_tokens"]) ?? 0

        let rawInput = intValue(usage["prompt_tokens"]) ?? intValue(usage["input_tokens"]) ?? 0
        // Anthropic reports uncached `input_tokens` separately from cache read/creation tokens.
        let isAnthropicSplit = usage["cache_read_input_tokens"] != nil || usage["cache_creation_input_tokens"] != nil
        let totalInput = isAnthropicSplit ? rawInput + cachedRead + cacheCreation : max(rawInput, cachedRead)

        let cost = doubleValue(usage["cost"]) ?? topCost
        let result = TokenUsage(
            inputTokens: totalInput,
            outputTokens: output,
            cachedInputTokens: cachedRead,
            costUSD: cost
        )
        return result.isEmpty ? nil : result
    }

    private static func intValue(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let integer = number.intValue
        return integer >= 0 ? integer : nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            let value = number.doubleValue
            return value.isFinite && value >= 0 ? value : nil
        }
        if let string = value as? String, let value = Double(string.trimmingCharacters(in: .whitespaces)),
           value.isFinite, value >= 0 {
            return value
        }
        return nil
    }
}

/// Aggregated request, token, and USD cost totals.
nonisolated struct UsageTotals: Hashable, Codable, Sendable {
    var requests = 0
    var inputTokens = 0
    var outputTokens = 0
    var costUSD = 0.0

    var totalTokens: Int { inputTokens + outputTokens }

    mutating func add(_ usage: TokenUsage) {
        requests += 1
        inputTokens += usage.inputTokens
        outputTokens += usage.outputTokens
        if let cost = usage.costUSD { costUSD += cost }
    }
}

/// Compact formatters for token counts, request counts, and USD cost.
nonisolated enum UsageFormatting {
    static func tokens(_ count: Int) -> String {
        switch count {
        case 1_000_000...:
            return String(format: "%.1fM", Double(count) / 1_000_000)
        case 10_000...:
            return String(format: "%.1fK", Double(count) / 1_000)
        case 1_000...:
            return String(format: "%.2fK", Double(count) / 1_000)
        default:
            return "\(count)"
        }
    }

    static func cost(_ usd: Double) -> String {
        guard usd.isFinite, usd > 0 else { return "$0.00" }
        if usd < 0.0001 { return "<$0.0001" }
        if usd < 0.01 { return String(format: "$%.4f", usd) }
        if usd < 1.0 { return String(format: "$%.3f", usd) }
        return String(format: "$%.2f", usd)
    }

    static func requests(_ count: Int) -> String {
        count == 1 ? "1 request" : "\(count.formatted()) requests"
    }
}

/// Persists today, all-time, and per-provider token and money metrics in UserDefaults.
@Observable
final class UsageTracker {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var dayKey: String

    private(set) var today: UsageTotals
    private(set) var allTime: UsageTotals
    private(set) var byProvider: [String: UsageTotals]

    private struct Snapshot: Codable {
        var dayKey: String
        var today: UsageTotals
        var allTime: UsageTotals
        var byProvider: [String: UsageTotals]
    }

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        let currentDay = Self.dayIdentifier(for: now)
        if let data = defaults.data(forKey: Self.storageKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            dayKey = currentDay
            today = snapshot.dayKey == currentDay ? snapshot.today : UsageTotals()
            allTime = snapshot.allTime
            byProvider = snapshot.byProvider
        } else {
            dayKey = currentDay
            today = UsageTotals()
            allTime = UsageTotals()
            byProvider = [:]
        }
    }

    func record(_ usage: TokenUsage, providerID: String, now: Date = Date()) {
        rolloverIfNeeded(now: now)
        today.add(usage)
        allTime.add(usage)
        var providerTotals = byProvider[providerID] ?? UsageTotals()
        providerTotals.add(usage)
        byProvider[providerID] = providerTotals
        save()
    }

    func refreshDay(now: Date = Date()) {
        rolloverIfNeeded(now: now)
    }

    func reset(now: Date = Date()) {
        dayKey = Self.dayIdentifier(for: now)
        today = UsageTotals()
        allTime = UsageTotals()
        byProvider = [:]
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// Providers with recorded usage, sorted by highest cost and then highest token total.
    var rankedProviders: [(provider: Provider, totals: UsageTotals)] {
        byProvider
            .map { (Provider.with(id: $0.key), $0.value) }
            .sorted { a, b in
                if a.1.costUSD != b.1.costUSD { return a.1.costUSD > b.1.costUSD }
                if a.1.totalTokens != b.1.totalTokens { return a.1.totalTokens > b.1.totalTokens }
                return a.0.name < b.0.name
            }
    }

    private func rolloverIfNeeded(now: Date) {
        let currentDay = Self.dayIdentifier(for: now)
        guard dayKey != currentDay else { return }
        dayKey = currentDay
        today = UsageTotals()
        save()
    }

    private func save() {
        let snapshot = Snapshot(dayKey: dayKey, today: today, allTime: allTime, byProvider: byProvider)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "usageMetricsV1"

    private static func dayIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
