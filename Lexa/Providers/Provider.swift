import Foundation

nonisolated enum ProviderKind: Sendable, Hashable {
    case openAICompatible
    case codexCLI
    case claudeCLI
}

nonisolated enum ProviderGroup: String, CaseIterable, Sendable {
    case free = "Free API Providers"
    case local = "Local"
    case subscription = "Subscriptions"
}

nonisolated struct Provider: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: ProviderKind
    let group: ProviderGroup
    var baseURL = ""
    var defaultModel = ""
    var suggestedModels: [String] = []
    var keyURL: URL?
    var needsKey = false
    var note = ""
    var extraHeaders: [String: String] = [:]
    /// Name of the CLI binary for subscription providers.
    var executable = ""

    var isCLI: Bool { kind != .openAICompatible }
    var allowsBaseURLEdit: Bool { kind == .openAICompatible && group == .local }
}

nonisolated extension Provider {
    static let openRouter = Provider(
        id: "openrouter", name: "OpenRouter", kind: .openAICompatible, group: .free,
        baseURL: "https://openrouter.ai/api/v1", defaultModel: "openrouter/free",
        suggestedModels: ["openrouter/free"],
        keyURL: URL(string: "https://openrouter.ai/keys"), needsKey: true,
        note: "Many models are free. The \"openrouter/free\" model selects a free model for you.",
        extraHeaders: ["HTTP-Referer": "https://github.com/SASUKE40/Lexa", "X-Title": "Lexa"])

    static let nous = Provider(
        id: "nous", name: "Nous Portal", kind: .openAICompatible, group: .free,
        baseURL: "https://inference-api.nousresearch.com/v1", defaultModel: "Hermes-4-70B",
        suggestedModels: ["Hermes-4-70B", "Hermes-4-405B"],
        keyURL: URL(string: "https://portal.nousresearch.com"), needsKey: true,
        note: "Hermes models from Nous Research.")

    static let groq = Provider(
        id: "groq", name: "Groq", kind: .openAICompatible, group: .free,
        baseURL: "https://api.groq.com/openai/v1", defaultModel: "llama-3.3-70b-versatile",
        suggestedModels: ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "openai/gpt-oss-120b"],
        keyURL: URL(string: "https://console.groq.com/keys"), needsKey: true,
        note: "Very fast models that are free to use, with a rate limit.")

    static let cerebras = Provider(
        id: "cerebras", name: "Cerebras", kind: .openAICompatible, group: .free,
        baseURL: "https://api.cerebras.ai/v1", defaultModel: "gpt-oss-120b",
        suggestedModels: ["gpt-oss-120b", "llama-3.3-70b", "qwen-3-32b"],
        keyURL: URL(string: "https://cloud.cerebras.ai"), needsKey: true,
        note: "Very fast models that are free to use, with a rate limit.")

    static let gemini = Provider(
        id: "gemini", name: "Google Gemini", kind: .openAICompatible, group: .free,
        baseURL: "https://generativelanguage.googleapis.com/v1beta/openai", defaultModel: "gemini-2.5-flash",
        suggestedModels: ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro"],
        keyURL: URL(string: "https://aistudio.google.com/apikey"), needsKey: true,
        note: "Free to use with an API key from Google AI Studio.")

    static let mistral = Provider(
        id: "mistral", name: "Mistral", kind: .openAICompatible, group: .free,
        baseURL: "https://api.mistral.ai/v1", defaultModel: "mistral-small-latest",
        suggestedModels: ["mistral-small-latest", "mistral-medium-latest", "open-mistral-nemo"],
        keyURL: URL(string: "https://console.mistral.ai/api-keys"), needsKey: true,
        note: "Free to use with the \"Experiment\" plan.")

    static let github = Provider(
        id: "github", name: "GitHub Models", kind: .openAICompatible, group: .free,
        baseURL: "https://models.github.ai/inference", defaultModel: "openai/gpt-4.1-mini",
        suggestedModels: ["openai/gpt-4.1-mini", "openai/gpt-4.1", "meta/llama-3.3-70b-instruct"],
        keyURL: URL(string: "https://github.com/settings/personal-access-tokens"), needsKey: true,
        note: "Use a GitHub token that has the \"models: read\" permission.")

    static let ollama = Provider(
        id: "ollama", name: "Ollama", kind: .openAICompatible, group: .local,
        baseURL: "http://localhost:11434/v1", defaultModel: "llama3.2",
        suggestedModels: ["llama3.2", "qwen3", "gemma3"],
        keyURL: URL(string: "https://ollama.com/download"),
        note: "The model operates on your Mac. Your text stays on your Mac.")

    static let lmStudio = Provider(
        id: "lmstudio", name: "LM Studio", kind: .openAICompatible, group: .local,
        baseURL: "http://localhost:1234/v1",
        keyURL: URL(string: "https://lmstudio.ai"),
        note: "Start the local server in LM Studio. Then download the model list.")

    static let custom = Provider(
        id: "custom", name: "Custom (OpenAI-compatible)", kind: .openAICompatible, group: .local,
        note: "Use a server that has an OpenAI-compatible /chat/completions endpoint.")

    static let codex = Provider(
        id: "codex", name: "ChatGPT (Codex CLI)", kind: .codexCLI, group: .subscription,
        suggestedModels: ["gpt-5.4-mini", "gpt-5.4"],
        keyURL: URL(string: "https://developers.openai.com/codex/cli"),
        note: "Uses your ChatGPT plan through the codex CLI. It is slower than an API provider.",
        executable: "codex")

    static let claude = Provider(
        id: "claude", name: "Claude (Claude Code CLI)", kind: .claudeCLI, group: .subscription,
        defaultModel: "haiku", suggestedModels: ["haiku", "sonnet", "opus"],
        keyURL: URL(string: "https://claude.com/product/claude-code"),
        note: "Uses your Claude plan through the claude CLI. It is slower than an API provider.",
        executable: "claude")

    static let all: [Provider] = [
        openRouter, nous, groq, cerebras, gemini, mistral, github,
        ollama, lmStudio, custom,
        codex, claude,
    ]

    static func with(id: String) -> Provider {
        all.first { $0.id == id } ?? openRouter
    }
}
