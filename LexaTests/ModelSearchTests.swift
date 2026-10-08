import Testing
@testable import Lexa

struct ModelSearchTests {
    let models = [
        "openrouter/free",
        "meta-llama/llama-3.3-70b-instruct:free",
        "qwen/qwen3-235b-a22b:free",
        "google/gemma-3-27b-it:free",
        "deepseek/deepseek-chat-v3:free",
        "nousresearch/hermes-3-llama-3.1-405b:free",
    ]

    @Test func emptyQueryKeepsEverythingInOrder() {
        #expect(ModelSearch.filter(models, query: "") == models)
        #expect(ModelSearch.filter(models, query: "   ") == models)
    }

    @Test func matchesCaseInsensitively() {
        #expect(ModelSearch.filter(models, query: "GEMMA") == ["google/gemma-3-27b-it:free"])
    }

    @Test func allWordsMustMatch() {
        #expect(ModelSearch.filter(models, query: "llama 70b") == ["meta-llama/llama-3.3-70b-instruct:free"])
        #expect(ModelSearch.filter(models, query: "llama 405") == ["nousresearch/hermes-3-llama-3.1-405b:free"])
        #expect(ModelSearch.filter(models, query: "llama gpt").isEmpty)
    }

    @Test func shortNamePrefixRanksFirst() {
        #expect(ModelSearch.filter(models, query: "llama") == [
            "meta-llama/llama-3.3-70b-instruct:free",
            "nousresearch/hermes-3-llama-3.1-405b:free",
        ])
        #expect(ModelSearch.filter(models, query: "hermes").first == "nousresearch/hermes-3-llama-3.1-405b:free")
    }

    @Test func matchesProviderPrefix() {
        #expect(ModelSearch.filter(models, query: "qwen/") == ["qwen/qwen3-235b-a22b:free"])
    }
}
