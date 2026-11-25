import Foundation
import Testing
@testable import Lexa

struct UsageMetricsTests {
    @Test func parsesOpenAIAndOpenRouterUsage() {
        let sse = #"data: {"choices":[],"usage":{"prompt_tokens":120,"completion_tokens":40,"prompt_tokens_details":{"cached_tokens":30},"cost":0.00042}}"#
        let usage = OpenAIStreamParser.parseUsage(line: sse)
        #expect(usage == TokenUsage(inputTokens: 120, outputTokens: 40, cachedInputTokens: 30, costUSD: 0.00042))
        #expect(OpenAIStreamParser.parseUsage(line: "data: [DONE]") == nil)

        let groq = Data(#"{"choices":[{"message":{"content":"ok"}}],"x_groq":{"usage":{"prompt_tokens":80,"completion_tokens":12}}}"#.utf8)
        #expect(OpenAIStreamParser.parseUsage(body: groq) == TokenUsage(inputTokens: 80, outputTokens: 12))
    }

    @Test func parsesClaudeResultUsageAndCost() {
        let line = #"{"type":"result","subtype":"success","is_error":false,"result":"Fixed.","total_cost_usd":0.0042,"usage":{"input_tokens":100,"cache_creation_input_tokens":200,"cache_read_input_tokens":500,"output_tokens":35}}"#
        let usage = ClaudeStreamParser.parseUsage(line: line)
        #expect(usage == TokenUsage(inputTokens: 800, outputTokens: 35, cachedInputTokens: 500, costUSD: 0.0042))
    }

    @Test func parsesCodexTurnCompletedUsage() {
        let line = #"{"type":"turn.completed","usage":{"input_tokens":16345,"cached_input_tokens":7168,"output_tokens":11}}"#
        let usage = CodexStreamParser.parseUsage(line: line)
        #expect(usage == TokenUsage(inputTokens: 16345, outputTokens: 11, cachedInputTokens: 7168, costUSD: nil))
    }

    @Test func estimatesCostFromCatalogPricingWithCacheDiscount() {
        let json = """
        {"data":[
          {"id":"google/gemini-2.5-flash","created":1750118400,"pricing":{"prompt":"0.0000003","completion":"0.0000025","input_cache_read":"0.000000075"}}
        ]}
        """
        let catalog = ModelCatalog.parseOpenRouterCatalog(Data(json.utf8))
        let pricing = ModelCatalog.lookupPricing(modelID: "gemini-2.5-flash-001", provider: .gemini, in: catalog)
        #expect(pricing != nil)

        let usage = TokenUsage(inputTokens: 1000, outputTokens: 200, cachedInputTokens: 400).withEstimatedCost(pricing)
        // 600 * 0.3e-6 + 400 * 0.075e-6 + 200 * 2.5e-6 = 0.00018 + 0.00003 + 0.0005 = 0.00071
        #expect(abs((usage.costUSD ?? 0) - 0.00071) < 1e-9)

        let freePricing = ModelCatalog.lookupPricing(modelID: "google/gemma-4-31b-it:free", provider: .openRouter, in: catalog)
        #expect(freePricing == .free)
    }

    @Test func formatsTokensAndCostClearly() {
        #expect(UsageFormatting.tokens(42) == "42")
        #expect(UsageFormatting.tokens(1_250) == "1.25K")
        #expect(UsageFormatting.tokens(14_200) == "14.2K")
        #expect(UsageFormatting.tokens(1_500_000) == "1.5M")

        #expect(UsageFormatting.cost(0) == "$0.00")
        #expect(UsageFormatting.cost(0.00002) == "<$0.0001")
        #expect(UsageFormatting.cost(0.0012) == "$0.0012")
        #expect(UsageFormatting.cost(0.042) == "$0.042")
        #expect(UsageFormatting.cost(2.5) == "$2.50")
    }

    @Test func trackerPersistsRollsOverDailyAndResets() throws {
        let suite = "lexa.tests.usage.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let day1 = Date(timeIntervalSince1970: 1_760_000_000)
        let day2 = day1.addingTimeInterval(24 * 60 * 60)

        let tracker = UsageTracker(defaults: defaults, now: day1)
        tracker.record(TokenUsage(inputTokens: 100, outputTokens: 50, costUSD: 0.002), providerID: Provider.gemini.id, now: day1)
        tracker.record(TokenUsage(inputTokens: 300, outputTokens: 100, costUSD: 0.010), providerID: Provider.claude.id, now: day1)

        #expect(tracker.today.requests == 2)
        #expect(tracker.today.totalTokens == 550)
        #expect(abs(tracker.today.costUSD - 0.012) < 1e-9)
        #expect(tracker.rankedProviders.map(\.provider.id) == [Provider.claude.id, Provider.gemini.id])

        // Next day: `today` resets while `allTime` and `byProvider` persist.
        let nextDayTracker = UsageTracker(defaults: defaults, now: day2)
        #expect(nextDayTracker.today.requests == 0)
        #expect(nextDayTracker.allTime.requests == 2)
        #expect(nextDayTracker.allTime.totalTokens == 550)

        nextDayTracker.reset(now: day2)
        #expect(nextDayTracker.allTime.requests == 0)
        #expect(nextDayTracker.byProvider.isEmpty)
    }
}
