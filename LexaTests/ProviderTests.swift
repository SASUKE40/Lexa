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

    @Test func preferencesPersist() throws {
        let suite = "lexa.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefs = Preferences(defaults: defaults)
        #expect(prefs.provider == .openRouter)
        #expect(prefs.model(for: .claude) == "haiku")
        prefs.providerID = Provider.groq.id
        prefs.models[Provider.groq.id] = "llama-3.1-8b-instant"
        prefs.hotKey = HotKeyCombo(keyCode: 5, modifiers: 256, key: "G")

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.provider == .groq)
        #expect(reloaded.model(for: .groq) == "llama-3.1-8b-instant")
        #expect(reloaded.hotKey.display == "⌘G")
    }
}
