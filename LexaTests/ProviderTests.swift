import CoreGraphics
import Foundation
import Testing
@testable import Lexa

struct ProviderTests {
    @Test func endpointJoinsWithoutDoubleSlashes() {
        #expect(OpenAICompatibleBackend.endpoint("https://x.ai/v1/", "chat/completions")?.absoluteString == "https://x.ai/v1/chat/completions")
        #expect(OpenAICompatibleBackend.endpoint(" https://x.ai/v1 ", "models")?.absoluteString == "https://x.ai/v1/models")
        #expect(OpenAICompatibleBackend.endpoint("", "models") == nil)
    }

    @Test func parseModelsOrdersByReleaseDateDescending() {
        let json = """
        {"data":[
          {"id":"alpha-old","created":1700000000},
          {"id":"zeta-newest","created":1760000000},
          {"id":"beta-mid","created":1730000000},
          {"id":"alpha-mid","created":1730000000}
        ]}
        """
        let models = ModelList.parse(Data(json.utf8), providerID: Provider.groq.id)
        #expect(models.map(\.id) == ["zeta-newest", "alpha-mid", "beta-mid", "alpha-old"])
        #expect(models.first?.releaseDate?.timestamp == 1760000000)
    }

    @Test func parseModelsOpenRouterKeepsFreeRouterFirstAndSortsFreeNewestFirst() {
        let json = """
        {"data":[
          {"id":"paid/newest","created":1799000000},
          {"id":"a/older:free","created":1710000000},
          {"id":"z/newest:free","created":1780000000},
          {"id":"m/mid:free","created":1750000000}
        ]}
        """
        let models = ModelList.parse(Data(json.utf8), providerID: Provider.openRouter.id)
        #expect(models.map(\.id) == ["openrouter/free", "z/newest:free", "m/mid:free", "a/older:free"])
        #expect(models[0].releaseDate == nil)
        #expect(models[1].releaseDate?.timestamp == 1780000000)
    }

    @Test func parseModelsPlacesUndatedModelsLastInAlphabeticalOrder() {
        let json = """
        {"data":[
          {"id":"models/zeta-undated"},
          {"id":"models/alpha-zero","created":0},
          {"id":"models/bool-date","created":true},
          {"id":"models/dated-model","created":1720000000}
        ]}
        """
        #expect(ModelList.parse(Data(json.utf8), providerID: Provider.gemini.id).map(\.id) == [
            "dated-model", "alpha-zero", "bool-date", "zeta-undated",
        ])
    }

    @Test func parseModelsSupportsISO8601ReleaseDatesAndMilliseconds() {
        let json = """
        {"models":[
          {"name":"from-date-only","release_date":"2025-03-01"},
          {"name":"from-iso-frac","created_at":"2025-06-15T12:30:00.123456Z"},
          {"name":"from-millis","created":1767225600000},
          {"name":"from-modified","modified_at":"2024-11-20T00:00:00Z"},
          {"name":"prefer-release-over-created","release_date":"2025-05-01","created":1790000000}
        ]}
        """
        #expect(ModelList.parse(Data(json.utf8), providerID: Provider.ollama.id).map(\.id) == [
            "from-millis",
            "from-iso-frac",
            "prefer-release-over-created",
            "from-date-only",
            "from-modified",
        ])
    }

    @Test func parseModelsSupportsTopLevelArrayAndDeduplicates() {
        let json = """
        [
          {"id":"dup-model","created":1710000000},
          {"id":"other-model","created":1720000000},
          {"id":"dup-model","created":1750000000}
        ]
        """
        #expect(ModelList.parse(Data(json.utf8), providerID: Provider.custom.id).map(\.id) == [
            "dup-model", "other-model",
        ])
    }

    @Test func parseModelsOrdersGeminiByKnownCatalogIDDatesAndVersionDesc() {
        let openRouterCatalog = """
        {"data":[
          {"id":"openai/gpt-5","created":1799999999},
          {"id":"google/gemini-2.5-flash","created":1750118400},
          {"id":"google/gemini-2.5-pro-preview","canonical_slug":"google/gemini-2.5-pro-preview-06-05","created":1749081600},
          {"id":"google/gemini-3.8-flash:batch","created":1788307200},
          {"id":"google/gemini-4-neon","created":1794960000}
        ]}
        """
        let knownDates = ModelCatalog.parseOpenRouterCatalog(Data(openRouterCatalog.utf8)).googleReleaseDates
        #expect(knownDates["openai/gpt-5"] == nil)
        #expect(knownDates["gemini-3.8-flash"]?.timestamp == 1788307200)
        #expect(knownDates["gemini-2.5-pro-preview-06-05"]?.timestamp == 1749081600)

        let geminiPayload = """
        {"data":[
          {"id":"models/gemini-1.5-pro","object":"model","owned_by":"google"},
          {"id":"models/gemini-2.0-flash","object":"model","owned_by":"google"},
          {"id":"models/gemini-2.5-flash","object":"model","owned_by":"google"},
          {"id":"models/gemini-2.5-flash-001","object":"model","owned_by":"google"},
          {"id":"models/gemini-2.5-flash-preview-09-2025","object":"model","owned_by":"google"},
          {"id":"models/gemini-2.5-pro-preview-06-05","object":"model","owned_by":"google"},
          {"id":"models/deep-research-preview-04-2026","object":"model","owned_by":"google"},
          {"id":"models/gemini-3.8-flash","object":"model","owned_by":"google"},
          {"id":"models/gemini-4-neon","object":"model","owned_by":"google"}
        ]}
        """
        let models = ModelList.parse(Data(geminiPayload.utf8), providerID: Provider.gemini.id, knownDates: knownDates)
        #expect(models.map(\.id) == [
            "gemini-4-neon",
            "gemini-3.8-flash",
            "deep-research-preview-04-2026",
            "gemini-2.5-flash-preview-09-2025",
            "gemini-2.5-flash",
            "gemini-2.5-flash-001",
            "gemini-2.5-pro-preview-06-05",
            "gemini-2.0-flash",
            "gemini-1.5-pro",
        ])
        #expect(models[0].releaseDate?.precision == .day)
        #expect(models[2].releaseDate?.precision == .month)
        #expect(models[7].releaseDate == nil)
    }

    @Test func releaseDateFromModelIDParsesExplicitDatesWithPrecision() {
        #expect(ModelList.releaseDate(fromModelID: "gemini-2.5-flash-preview-09-2025")?.precision == .month)
        #expect(ModelList.releaseDate(fromModelID: "gpt-4o-2024-11-20")?.precision == .day)
        #expect(ModelList.releaseDate(fromModelID: "claude-3-5-sonnet-20241022")?.precision == .day)
        #expect(ModelList.releaseDate(fromModelID: "model-2025-05")?.precision == .month)
        #expect(ModelList.releaseDate(fromModelID: "gemini-2.0-flash-001") == nil)
        #expect(ModelList.releaseDate(fromModelID: "gemma-3-27b-it") == nil)
    }

    @Test func parseModelsUndatedOrderingIsConsistentAndSkipsEmptyPrefix() {
        let json = """
        {"data":[
          {"id":"models/"},
          {"id":"a-1."},
          {"id":"a-1"},
          {"id":"a-2"},
          {"id":"gemini-3.2-flash"},
          {"id":"gemini-3.10-flash"},
          {"id":"gemini-2-pro"},
          {"id":"gemini-2.0-flash"},
          {"id":"gemini-flash-latest"}
        ]}
        """
        #expect(ModelList.parse(Data(json.utf8), providerID: Provider.gemini.id).map(\.id) == [
            "a-2",
            "a-1",
            "a-1.",
            "gemini-3.10-flash",
            "gemini-3.2-flash",
            "gemini-2-pro",
            "gemini-2.0-flash",
            "gemini-flash-latest",
        ])
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

    @Test func localSecretStoreRoundTripsWithOwnerOnlyPermissions() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "lexa-secrets-\(UUID().uuidString)")
        let file = dir.appending(path: "secrets.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(Keychain.readLocal("gemini", from: file) == nil)
        Keychain.saveLocal("test-secret-key", for: "gemini", to: file)
        #expect(Keychain.readLocal("gemini", from: file) == "test-secret-key")

        let fileAttrs = try FileManager.default.attributesOfItem(atPath: file.path)
        let dirAttrs = try FileManager.default.attributesOfItem(atPath: dir.path)
        #expect((fileAttrs[.posixPermissions] as? Int) == 0o600)
        #expect((dirAttrs[.posixPermissions] as? Int) == 0o700)

        Keychain.saveLocal("", for: "gemini", to: file)
        #expect(Keychain.readLocal("gemini", from: file) == nil)
    }

    @Test func textBridgeDetectsConflictingModifiersAndSlicesUTF16Safely() {
        #expect(TextBridge.hasConflictingModifiers(.maskAlternate))
        #expect(TextBridge.hasConflictingModifiers([.maskCommand, .maskAlternate]))
        #expect(TextBridge.hasConflictingModifiers(.maskControl))
        #expect(TextBridge.hasConflictingModifiers(.maskShift))
        #expect(!TextBridge.hasConflictingModifiers(.maskCommand))
        #expect(!TextBridge.hasConflictingModifiers([]))

        // Emoji takes 2 UTF-16 code units; AXSelectedTextRange reports UTF-16 offsets.
        let sample = "Hi 👋 world"
        #expect(TextBridge.sliceUTF16(sample, location: 3, length: 2) == "👋")
        #expect(TextBridge.sliceUTF16(sample, location: 6, length: 5) == "world")
        #expect(TextBridge.sliceUTF16(sample, location: 0, length: 0) == nil)
        #expect(TextBridge.sliceUTF16(sample, location: -1, length: 2) == nil)
        #expect(TextBridge.sliceUTF16(sample, location: 8, length: 10) == nil)
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
