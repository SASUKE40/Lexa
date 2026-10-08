import Foundation
import Observation

/// User preferences persisted in UserDefaults. API keys live in the Keychain, not here.
@Observable
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    var providerID: String { didSet { defaults.set(providerID, forKey: Keys.provider) } }
    var models: [String: String] { didSet { defaults.set(models, forKey: Keys.models) } }
    var baseURLs: [String: String] { didSet { defaults.set(baseURLs, forKey: Keys.baseURLs) } }
    var cliPaths: [String: String] { didSet { defaults.set(cliPaths, forKey: Keys.cliPaths) } }
    var defaultActionID: String { didSet { defaults.set(defaultActionID, forKey: Keys.defaultAction) } }
    var translateLanguage: String { didSet { defaults.set(translateLanguage, forKey: Keys.language) } }
    var autoRun: Bool { didSet { defaults.set(autoRun, forKey: Keys.autoRun) } }
    var findUpdates: Bool { didSet { defaults.set(findUpdates, forKey: Keys.findUpdates) } }
    var hasCompletedSetup: Bool { didSet { defaults.set(hasCompletedSetup, forKey: Keys.setup) } }
    var hotKey: HotKeyCombo {
        didSet { defaults.set(try? JSONEncoder().encode(hotKey), forKey: Keys.hotKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        providerID = defaults.string(forKey: Keys.provider) ?? Provider.openRouter.id
        models = defaults.dictionary(forKey: Keys.models) as? [String: String] ?? [:]
        baseURLs = defaults.dictionary(forKey: Keys.baseURLs) as? [String: String] ?? [:]
        cliPaths = defaults.dictionary(forKey: Keys.cliPaths) as? [String: String] ?? [:]
        defaultActionID = defaults.string(forKey: Keys.defaultAction) ?? WritingAction.fix.id
        translateLanguage = defaults.string(forKey: Keys.language) ?? "English"
        autoRun = defaults.object(forKey: Keys.autoRun) as? Bool ?? true
        findUpdates = defaults.object(forKey: Keys.findUpdates) as? Bool ?? true
        hasCompletedSetup = defaults.bool(forKey: Keys.setup)
        hotKey = defaults.data(forKey: Keys.hotKey).flatMap { try? JSONDecoder().decode(HotKeyCombo.self, from: $0) } ?? .default

        // Version 2 moves ChatGPT and Claude to their newest models, so old saved choices are cleared once.
        if defaults.integer(forKey: Keys.modelDefaults) < 2 {
            models[Provider.claude.id] = nil
            models[Provider.codex.id] = nil
            defaults.set(models, forKey: Keys.models)
            defaults.set(2, forKey: Keys.modelDefaults)
        }
    }

    var provider: Provider { Provider.with(id: providerID) }

    var defaultAction: WritingAction {
        WritingAction(id: defaultActionID, language: translateLanguage) ?? .fix
    }

    func model(for provider: Provider) -> String { models[provider.id] ?? provider.defaultModel }
    func baseURL(for provider: Provider) -> String { baseURLs[provider.id] ?? provider.baseURL }
    func cliPath(for provider: Provider) -> String { cliPaths[provider.id] ?? "" }

    private enum Keys {
        static let provider = "provider"
        static let models = "models"
        static let baseURLs = "baseURLs"
        static let cliPaths = "cliPaths"
        static let defaultAction = "defaultAction"
        static let language = "translateLanguage"
        static let autoRun = "autoRun"
        static let findUpdates = "findUpdates"
        static let setup = "hasCompletedSetup"
        static let hotKey = "hotKey"
        static let modelDefaults = "modelDefaultsVersion"
    }
}
