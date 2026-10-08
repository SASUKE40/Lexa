import Foundation
import Testing
@testable import Lexa

struct ProviderTests {
    @Test func endpointJoinsWithoutDoubleSlashes() {
        #expect(OpenAICompatibleBackend.endpoint("https://x.ai/v1/", "chat/completions")?.absoluteString == "https://x.ai/v1/chat/completions")
        #expect(OpenAICompatibleBackend.endpoint(" https://x.ai/v1 ", "models")?.absoluteString == "https://x.ai/v1/models")
        #expect(OpenAICompatibleBackend.endpoint("", "models") == nil)
    }

    @Test func providerIDsAreUnique() {
        #expect(Set(Provider.all.map(\.id)).count == Provider.all.count)
    }

    @Test func presetsAreConfigured() {
        for provider in Provider.all {
            switch provider.kind {
            case .openAICompatible where provider.id != Provider.custom.id:
                let url = URL(string: provider.baseURL)
                #expect(url?.scheme == (provider.group == .local ? "http" : "https"), "\(provider.id)")
                #expect(provider.needsKey == (provider.group == .free), "\(provider.id)")
            case .codexCLI, .claudeCLI:
                #expect(!provider.executable.isEmpty)
                #expect(!provider.needsKey)
            default:
                break
            }
        }
    }

    @Test func unknownProviderFallsBackToOpenRouter() {
        #expect(Provider.with(id: "nope") == .openRouter)
    }

    @Test func actionIDsRoundTrip() {
        let actions: [WritingAction] = [.fix, .improve, .translate("French")] + Tone.allCases.map { .tone($0) }
        for action in actions {
            #expect(WritingAction(id: action.id, language: "French") == action)
        }
        #expect(WritingAction(id: "bogus", language: "English") == nil)
    }

    @Test func promptWrapsTextAndCarriesInstructions() {
        let request = PromptBuilder.request(action: .translate("German"), text: "Hello", model: "m")
        #expect(request.user == "<text>\nHello\n</text>")
        #expect(request.system.contains("German"))
        #expect(request.system.contains("Send ONLY the changed text"))
        #expect(request.model == "m")
    }

    @Test func makeClearUsesSimplifiedTechnicalEnglish() {
        let system = PromptBuilder.request(action: .improve, text: "x", model: "m").system
        #expect(system.contains("ASD-STE100 Simplified Technical English"))
        #expect(system.contains("20 words"))
        #expect(system.contains("active voice"))
        #expect(WritingAction.improve.temperature == 0.2)
        #expect(WritingAction.improve.help.contains("ASD-STE100"))
    }

    @Test func preferencesPersist() throws {
        let suite = "lexa.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefs = Preferences(defaults: defaults)
        #expect(prefs.provider == .openRouter)
        #expect(prefs.model(for: .claude) == "opus")
        #expect(prefs.model(for: .codex) == CodexModels.available().first)
        prefs.providerID = Provider.groq.id
        prefs.models[Provider.groq.id] = "llama-3.1-8b-instant"
        prefs.hotKey = HotKeyCombo(keyCode: 5, modifiers: 256, key: "G")

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.provider == .groq)
        #expect(reloaded.model(for: .groq) == "llama-3.1-8b-instant")
        #expect(reloaded.hotKey.display == "⌘G")
    }
}

struct CodexModelsTests {
    @Test func sortsVisibleModelsByPriority() {
        let json = #"{"models":[{"slug":"gpt-6-astra","visibility":"list","priority":2},{"slug":"gpt-reserve","visibility":"hide","priority":1},{"slug":"gpt-6.1-sol","visibility":"list","priority":0}]}"#
        #expect(CodexModels.parse(Data(json.utf8)) == ["gpt-6.1-sol", "gpt-6-astra"])
    }

    @Test func fallsBackWhenTheCacheIsMissingOrBroken() {
        #expect(CodexModels.available(cache: URL(fileURLWithPath: "/nonexistent/models_cache.json")) == CodexModels.fallback)
        #expect(CodexModels.parse(Data("not json".utf8)).isEmpty)
    }

    @Test func oldSavedChoicesAreClearedOnce() throws {
        let suite = "lexa.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["claude": "haiku", "codex": "", "groq": "llama-3.1-8b-instant"], forKey: "models")

        let prefs = Preferences(defaults: defaults)
        #expect(prefs.model(for: .claude) == "opus")
        #expect(prefs.models["groq"] == "llama-3.1-8b-instant")

        prefs.models[Provider.claude.id] = "haiku"
        #expect(Preferences(defaults: defaults).model(for: .claude) == "haiku")
    }
}
