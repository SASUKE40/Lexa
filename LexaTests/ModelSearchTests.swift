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

    @Test func preservesReleaseDateMetadataWhileFiltering() {
        let items = [
            ModelInfo(id: "google/gemma-4-31b-it:free", releaseDate: ModelReleaseDate(timestamp: 1775148486)),
            ModelInfo(id: "google/gemma-3-27b-it:free", releaseDate: ModelReleaseDate(timestamp: 1741756359)),
        ]
        let result = ModelSearch.filter(items, query: "gemma")
        #expect(result == items)
    }

    @Test func detectsModelBrandsAcrossProvidersAndFamilies() {
        #expect(ModelBrand.detect(modelID: "gemini-4-neon") == .google)
        #expect(ModelBrand.detect(modelID: "google/gemma-4-31b-it:free") == .google)
        #expect(ModelBrand.detect(modelID: "gpt-6.1-sol") == .openAI)
        #expect(ModelBrand.detect(modelID: "openai/gpt-oss-120b") == .openAI)
        #expect(ModelBrand.detect(modelID: "opus", providerID: Provider.claude.id) == .anthropic)
        #expect(ModelBrand.detect(modelID: "claude-sonnet-4") == .anthropic)
        #expect(ModelBrand.detect(modelID: "llama-3.3-70b-versatile") == .meta)
        #expect(ModelBrand.detect(modelID: "mistral-small-latest") == .mistral)
        #expect(ModelBrand.detect(modelID: "deepseek/deepseek-chat-v3:free") == .deepSeek)
        #expect(ModelBrand.detect(modelID: "qwen/qwen3-235b-a22b:free") == .qwen)
        #expect(ModelBrand.detect(modelID: "grok-4.7") == .xAI)
        #expect(ModelBrand.detect(modelID: "Hermes-4-70B") == .nous)
        #expect(ModelBrand.detect(modelID: "nvidia/nemotron-3.5-super-vl:free") == .nvidia)
        #expect(ModelBrand.detect(modelID: "openrouter/free") == .openRouter)
        #expect(ModelBrand.detect(modelID: "baidu/ernie-5.5-flash-preview:free") == .baidu)
        #expect(ModelBrand.detect(modelID: "xiaomi/mimo-v2.6-flash-mopd") == .xiaomi)
        #expect(ModelBrand.detect(modelID: "liquid/lfm-3-1.7b:free") == .liquid)
        #expect(ModelBrand.detect(modelID: "stepfun/step-5-preview:free") == .stepFun)
        #expect(ModelBrand.detect(modelID: "unknown-local-model", providerID: Provider.ollama.id) == .ollama)
        #expect(ModelBrand.detect(modelID: "unknown-custom-model", providerID: Provider.custom.id) == .generic)
    }
}
