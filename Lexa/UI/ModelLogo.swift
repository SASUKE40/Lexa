import SwiftUI

/// Identifies the model or provider brand so Lexa can show a consistent vector logo everywhere.
nonisolated enum ModelBrand: String, CaseIterable, Hashable, Sendable {
    case google
    case openAI
    case anthropic
    case meta
    case mistral
    case deepSeek
    case qwen
    case xAI
    case nous
    case nvidia
    case groq
    case cerebras
    case openRouter
    case gitHub
    case ollama
    case lmStudio
    case cohere
    case microsoft
    case perplexity
    case baidu
    case xiaomi
    case moonshot
    case zhipu
    case miniMax
    case liquid
    case stepFun
    case generic

    /// Detects the brand from a model ID (vendor prefix first, then model family, then provider fallback).
    static func detect(modelID: String, providerID: String? = nil) -> ModelBrand {
        let lower = modelID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Explicit vendor prefix (e.g. "google/gemma-4-31b-it:free", "openai/gpt-oss-120b").
        if let slash = lower.firstIndex(of: "/") {
            let vendor = String(lower[..<slash])
            if let brand = brandFromVendor(vendor) { return brand }
        }

        // 2. Model family name (after any "/").
        let short = lower.split(separator: "/").last.map(String.init) ?? lower
        if let brand = brandFromModelName(short) { return brand }

        // 3. Provider fallback (e.g. empty default model on Claude/Codex or custom local model).
        if let providerID { return forProvider(providerID) }
        return .generic
    }

    static func forProvider(_ providerID: String) -> ModelBrand {
        switch providerID {
        case Provider.openRouter.id: .openRouter
        case Provider.nous.id: .nous
        case Provider.groq.id: .groq
        case Provider.cerebras.id: .cerebras
        case Provider.gemini.id: .google
        case Provider.mistral.id: .mistral
        case Provider.github.id: .gitHub
        case Provider.ollama.id: .ollama
        case Provider.lmStudio.id: .lmStudio
        case Provider.codex.id: .openAI
        case Provider.claude.id: .anthropic
        default: .generic
        }
    }

    private static func brandFromVendor(_ vendor: String) -> ModelBrand? {
        switch vendor {
        case "google", "deepmind": .google
        case "openai": .openAI
        case "anthropic": .anthropic
        case "meta", "meta-llama": .meta
        case "mistralai", "mistral": .mistral
        case "deepseek": .deepSeek
        case "qwen", "alibaba": .qwen
        case "x-ai", "xai": .xAI
        case "nousresearch", "nous": .nous
        case "nvidia": .nvidia
        case "openrouter": .openRouter
        case "cohere": .cohere
        case "microsoft": .microsoft
        case "perplexity": .perplexity
        case "baidu": .baidu
        case "xiaomi": .xiaomi
        case "moonshotai", "moonshot": .moonshot
        case "z-ai", "zhipu", "thudm": .zhipu
        case "minimax": .miniMax
        case "liquid": .liquid
        case "stepfun": .stepFun
        default: nil
        }
    }

    private static func brandFromModelName(_ name: String) -> ModelBrand? {
        if name.hasPrefix("gemini") || name.hasPrefix("gemma") || name.hasPrefix("imagen")
            || name.hasPrefix("veo") || name.hasPrefix("lyria") || name.hasPrefix("palm")
            || name.hasPrefix("deep-research") || name.hasPrefix("nano-banana") || name.hasPrefix("learnlm") {
            return .google
        }
        if name.hasPrefix("gpt") || name.hasPrefix("chatgpt") || name.hasPrefix("codex")
            || name.hasPrefix("o1") || name.hasPrefix("o3") || name.hasPrefix("o4")
            || name.hasPrefix("dall-e") || name.hasPrefix("whisper") {
            return .openAI
        }
        if name.hasPrefix("claude") || name == "opus" || name == "sonnet" || name == "haiku" || name == "fable" {
            return .anthropic
        }
        if name.hasPrefix("llama") || name.contains("llama-") || name.contains("llama3") || name.contains("llama4") {
            return .meta
        }
        if name.hasPrefix("mistral") || name.hasPrefix("mixtral") || name.hasPrefix("codestral")
            || name.hasPrefix("pixtral") || name.hasPrefix("ministral") || name.hasPrefix("devstral")
            || name.hasPrefix("magistral") || name.hasPrefix("open-mistral") || name.hasPrefix("open-mixtral") {
            return .mistral
        }
        if name.hasPrefix("deepseek") { return .deepSeek }
        if name.hasPrefix("qwen") || name.hasPrefix("qwq") { return .qwen }
        if name.hasPrefix("grok") { return .xAI }
        if name.hasPrefix("hermes") || name.hasPrefix("nous") { return .nous }
        if name.hasPrefix("nemotron") { return .nvidia }
        if name.hasPrefix("command") || name.hasPrefix("aya") { return .cohere }
        if name.hasPrefix("phi-") || name.hasPrefix("phi3") || name.hasPrefix("phi4") || name.hasPrefix("mai-") {
            return .microsoft
        }
        if name.hasPrefix("sonar") { return .perplexity }
        if name.hasPrefix("ernie") { return .baidu }
        if name.hasPrefix("mimo") { return .xiaomi }
        if name.hasPrefix("kimi") || name.hasPrefix("moonshot") { return .moonshot }
        if name.hasPrefix("glm") || name.hasPrefix("chatglm") { return .zhipu }
        if name.hasPrefix("minimax") || name.hasPrefix("abab") { return .miniMax }
        if name.hasPrefix("lfm") || name.hasPrefix("liquid") { return .liquid }
        if name.hasPrefix("step-") || name.hasPrefix("stepfun") { return .stepFun }
        return nil
    }
}

/// A crisp vector brand badge for any model or provider.
struct ModelLogo: View {
    let brand: ModelBrand
    var size: CGFloat = 16

    init(brand: ModelBrand, size: CGFloat = 16) {
        self.brand = brand
        self.size = size
    }

    init(modelID: String, providerID: String? = nil, size: CGFloat = 16) {
        self.brand = ModelBrand.detect(modelID: modelID, providerID: providerID)
        self.size = size
    }

    init(provider: Provider, size: CGFloat = 16) {
        self.brand = ModelBrand.forProvider(provider.id)
        self.size = size
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(accentColor.opacity(0.14))
            glyph
                .frame(width: size * 0.64, height: size * 0.64)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var accentColor: Color {
        switch brand {
        case .google: Color(red: 0.29, green: 0.52, blue: 0.96)
        case .openAI: Color(red: 0.06, green: 0.64, blue: 0.50)
        case .anthropic: Color(red: 0.85, green: 0.47, blue: 0.34)
        case .meta: Color(red: 0.03, green: 0.41, blue: 0.88)
        case .mistral: Color(red: 0.98, green: 0.38, blue: 0.10)
        case .deepSeek: Color(red: 0.30, green: 0.42, blue: 1.0)
        case .qwen: Color(red: 0.42, green: 0.36, blue: 0.93)
        case .xAI: .primary
        case .nous: Color(red: 0.82, green: 0.61, blue: 0.20)
        case .nvidia: Color(red: 0.46, green: 0.73, blue: 0.0)
        case .groq: Color(red: 0.96, green: 0.31, blue: 0.21)
        case .cerebras: Color(red: 0.50, green: 0.38, blue: 1.0)
        case .openRouter: Color(red: 0.39, green: 0.40, blue: 0.95)
        case .gitHub: Color(red: 0.55, green: 0.36, blue: 0.96)
        case .ollama: .primary
        case .lmStudio: Color(red: 0.49, green: 0.23, blue: 0.93)
        case .cohere: Color(red: 0.24, green: 0.58, blue: 0.50)
        case .microsoft: Color(red: 0.0, green: 0.64, blue: 0.94)
        case .perplexity: Color(red: 0.13, green: 0.52, blue: 0.56)
        case .baidu: Color(red: 0.18, green: 0.24, blue: 0.90)
        case .xiaomi: Color(red: 1.0, green: 0.41, blue: 0.0)
        case .moonshot: Color(red: 0.22, green: 0.68, blue: 0.96)
        case .zhipu: Color(red: 0.23, green: 0.51, blue: 0.96)
        case .miniMax: Color(red: 0.95, green: 0.25, blue: 0.37)
        case .liquid: Color(red: 0.04, green: 0.68, blue: 0.82)
        case .stepFun: Color(red: 0.15, green: 0.42, blue: 0.92)
        case .generic: .secondary
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch brand {
        case .google:
            GeminiSparkleShape()
                .fill(LinearGradient(
                    colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.61, green: 0.45, blue: 0.80)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        case .openAI:
            OpenAIRosetteShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.085, 1.1), lineCap: .round, lineJoin: .round))
        case .anthropic:
            AnthropicMarkShape()
                .fill(accentColor)
        case .meta:
            MetaLoopShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.105, 1.3), lineCap: .round, lineJoin: .round))
        case .mistral:
            MistralMShape()
                .fill(accentColor)
        case .deepSeek:
            WaveFinShape()
                .fill(accentColor)
        case .qwen:
            HexStarShape()
                .fill(accentColor)
        case .xAI:
            XAISlashShape()
                .fill(accentColor)
        case .nous:
            NousMarkShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.11, 1.3), lineCap: .round, lineJoin: .round))
        case .nvidia:
            NvidiaEyeShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.105, 1.2), lineCap: .round, lineJoin: .round))
        case .groq:
            Image(systemName: "bolt.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(accentColor)
        case .cerebras:
            CerebrasGridShape()
                .fill(accentColor)
        case .openRouter:
            OpenRouterShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.10, 1.2), lineCap: .round, lineJoin: .round))
        case .gitHub:
            GitBranchShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.10, 1.2), lineCap: .round, lineJoin: .round))
        case .ollama:
            OllamaSilhouetteShape()
                .fill(accentColor)
        case .lmStudio:
            Image(systemName: "cube.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(accentColor)
        case .cohere:
            CoherePebblesShape()
                .fill(accentColor)
        case .microsoft:
            MicrosoftGridShape()
                .fill(accentColor)
        case .perplexity:
            PerplexityPrismShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.095, 1.1), lineCap: .round, lineJoin: .round))
        case .baidu:
            BaiduPawShape()
                .fill(accentColor)
        case .xiaomi:
            XiaomiArchShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.11, 1.3), lineCap: .round, lineJoin: .round))
        case .moonshot:
            Image(systemName: "moon.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(accentColor)
        case .zhipu:
            ZhipuZShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: max(size * 0.11, 1.3), lineCap: .round, lineJoin: .round))
        case .miniMax:
            MiniMaxBarsShape()
                .fill(accentColor)
        case .liquid:
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(accentColor)
        case .stepFun:
            StepFunShape()
                .fill(accentColor)
        case .generic:
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .foregroundStyle(accentColor)
        }
    }
}

// MARK: - Vector Brand Shapes

nonisolated private struct GeminiSparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        var p = Path()
        p.move(to: CGPoint(x: cx, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: cy), control: CGPoint(x: cx, y: cy))
        p.addQuadCurve(to: CGPoint(x: cx, y: rect.maxY), control: CGPoint(x: cx, y: cy))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: cy), control: CGPoint(x: cx, y: cy))
        p.addQuadCurve(to: CGPoint(x: cx, y: rect.minY), control: CGPoint(x: cx, y: cy))
        p.closeSubpath()
        return p
    }
}

nonisolated private struct OpenAIRosetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let r = min(rect.width, rect.height) * 0.28
        let offset = min(rect.width, rect.height) * 0.21
        var p = Path()
        for i in 0..<6 {
            let angle = Double(i) * (.pi / 3.0)
            let x = cx + CGFloat(cos(angle)) * offset
            let y = cy + CGFloat(sin(angle)) * offset
            p.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        return p
    }
}

nonisolated private struct AnthropicMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        // Left A-leg + crossbar
        p.move(to: CGPoint(x: x0 + w * 0.06, y: y0 + h * 0.92))
        p.addLine(to: CGPoint(x: x0 + w * 0.34, y: y0 + h * 0.08))
        p.addLine(to: CGPoint(x: x0 + w * 0.49, y: y0 + h * 0.08))
        p.addLine(to: CGPoint(x: x0 + w * 0.72, y: y0 + h * 0.92))
        p.addLine(to: CGPoint(x: x0 + w * 0.56, y: y0 + h * 0.92))
        p.addLine(to: CGPoint(x: x0 + w * 0.50, y: y0 + h * 0.70))
        p.addLine(to: CGPoint(x: x0 + w * 0.27, y: y0 + h * 0.70))
        p.addLine(to: CGPoint(x: x0 + w * 0.21, y: y0 + h * 0.92))
        p.closeSubpath()
        // Right parallel diagonal slash
        p.move(to: CGPoint(x: x0 + w * 0.62, y: y0 + h * 0.08))
        p.addLine(to: CGPoint(x: x0 + w * 0.77, y: y0 + h * 0.08))
        p.addLine(to: CGPoint(x: x0 + w * 0.97, y: y0 + h * 0.92))
        p.addLine(to: CGPoint(x: x0 + w * 0.82, y: y0 + h * 0.92))
        p.closeSubpath()
        return p
    }
}

nonisolated private struct MetaLoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x0 + w * 0.50, y: y0 + h * 0.50))
        p.addCurve(
            to: CGPoint(x: x0 + w * 0.08, y: y0 + h * 0.55),
            control1: CGPoint(x: x0 + w * 0.36, y: y0 + h * 0.15),
            control2: CGPoint(x: x0 + w * 0.08, y: y0 + h * 0.15)
        )
        p.addCurve(
            to: CGPoint(x: x0 + w * 0.50, y: y0 + h * 0.50),
            control1: CGPoint(x: x0 + w * 0.08, y: y0 + h * 0.90),
            control2: CGPoint(x: x0 + w * 0.36, y: y0 + h * 0.82)
        )
        p.addCurve(
            to: CGPoint(x: x0 + w * 0.92, y: y0 + h * 0.55),
            control1: CGPoint(x: x0 + w * 0.64, y: y0 + h * 0.15),
            control2: CGPoint(x: x0 + w * 0.92, y: y0 + h * 0.15)
        )
        p.addCurve(
            to: CGPoint(x: x0 + w * 0.50, y: y0 + h * 0.50),
            control1: CGPoint(x: x0 + w * 0.92, y: y0 + h * 0.90),
            control2: CGPoint(x: x0 + w * 0.64, y: y0 + h * 0.82)
        )
        return p
    }
}

nonisolated private struct MistralMShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = min(rect.width, rect.height) / 5.0
        let ox = rect.midX - u * 2.5
        let oy = rect.midY - u * 2.0
        let blocks: [(Int, Int)] = [
            (0, 0), (4, 0),
            (0, 1), (1, 1), (3, 1), (4, 1),
            (0, 2), (2, 2), (4, 2),
            (0, 3), (4, 3),
        ]
        var p = Path()
        for (c, r) in blocks {
            p.addRect(CGRect(x: ox + CGFloat(c) * u, y: oy + CGFloat(r) * u, width: u, height: u))
        }
        return p
    }
}

nonisolated private struct WaveFinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x0 + w * 0.08, y: y0 + h * 0.72))
        p.addCurve(
            to: CGPoint(x: x0 + w * 0.86, y: y0 + h * 0.24),
            control1: CGPoint(x: x0 + w * 0.24, y: y0 + h * 0.18),
            control2: CGPoint(x: x0 + w * 0.64, y: y0 + h * 0.08)
        )
        p.addCurve(
            to: CGPoint(x: x0 + w * 0.92, y: y0 + h * 0.76),
            control1: CGPoint(x: x0 + w * 0.74, y: y0 + h * 0.48),
            control2: CGPoint(x: x0 + w * 0.84, y: y0 + h * 0.62)
        )
        p.addQuadCurve(to: CGPoint(x: x0 + w * 0.08, y: y0 + h * 0.72), control: CGPoint(x: x0 + w * 0.48, y: y0 + h * 0.94))
        p.closeSubpath()
        return p
    }
}

nonisolated private struct HexStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let outer = min(rect.width, rect.height) * 0.48
        let inner = outer * 0.46
        var p = Path()
        for i in 0..<12 {
            let angle = Double(i) * (.pi / 6.0) - (.pi / 2.0)
            let radius = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: cx + CGFloat(cos(angle)) * radius, y: cy + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

nonisolated private struct XAISlashShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        // Main ascending slash
        p.move(to: CGPoint(x: x0 + w * 0.14, y: y0 + h * 0.92))
        p.addLine(to: CGPoint(x: x0 + w * 0.72, y: y0 + h * 0.08))
        p.addLine(to: CGPoint(x: x0 + w * 0.90, y: y0 + h * 0.08))
        p.addLine(to: CGPoint(x: x0 + w * 0.32, y: y0 + h * 0.92))
        p.closeSubpath()
        // Counter-stroke upper-left
        p.move(to: CGPoint(x: x0 + w * 0.14, y: y0 + h * 0.12))
        p.addLine(to: CGPoint(x: x0 + w * 0.34, y: y0 + h * 0.12))
        p.addLine(to: CGPoint(x: x0 + w * 0.49, y: y0 + h * 0.38))
        p.addLine(to: CGPoint(x: x0 + w * 0.36, y: y0 + h * 0.50))
        p.closeSubpath()
        // Counter-stroke lower-right
        p.move(to: CGPoint(x: x0 + w * 0.60, y: y0 + h * 0.58))
        p.addLine(to: CGPoint(x: x0 + w * 0.74, y: y0 + h * 0.48))
        p.addLine(to: CGPoint(x: x0 + w * 0.90, y: y0 + h * 0.92))
        p.addLine(to: CGPoint(x: x0 + w * 0.70, y: y0 + h * 0.92))
        p.closeSubpath()
        return p
    }
}

nonisolated private struct NousMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x0 + w * 0.16, y: y0 + h * 0.88))
        p.addLine(to: CGPoint(x: x0 + w * 0.16, y: y0 + h * 0.14))
        p.addLine(to: CGPoint(x: x0 + w * 0.84, y: y0 + h * 0.86))
        p.addLine(to: CGPoint(x: x0 + w * 0.84, y: y0 + h * 0.12))
        return p
    }
}

nonisolated private struct NvidiaEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x0 + w * 0.08, y: y0 + h * 0.52))
        p.addQuadCurve(to: CGPoint(x: x0 + w * 0.92, y: y0 + h * 0.52), control: CGPoint(x: x0 + w * 0.50, y: y0 + h * 0.06))
        p.addQuadCurve(to: CGPoint(x: x0 + w * 0.24, y: y0 + h * 0.56), control: CGPoint(x: x0 + w * 0.54, y: y0 + h * 0.94))
        p.addQuadCurve(to: CGPoint(x: x0 + w * 0.72, y: y0 + h * 0.52), control: CGPoint(x: x0 + w * 0.48, y: y0 + h * 0.28))
        return p
    }
}

nonisolated private struct CerebrasGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let r = min(rect.width, rect.height) * 0.46
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - r))
        p.addLine(to: CGPoint(x: cx + r, y: cy))
        p.addLine(to: CGPoint(x: cx, y: cy + r))
        p.addLine(to: CGPoint(x: cx - r, y: cy))
        p.closeSubpath()
        return p
    }
}

nonisolated private struct OpenRouterShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x0 + w * 0.12, y: y0 + h * 0.50))
        p.addLine(to: CGPoint(x: x0 + w * 0.46, y: y0 + h * 0.50))
        p.addLine(to: CGPoint(x: x0 + w * 0.84, y: y0 + h * 0.20))
        p.move(to: CGPoint(x: x0 + w * 0.46, y: y0 + h * 0.50))
        p.addLine(to: CGPoint(x: x0 + w * 0.84, y: y0 + h * 0.80))
        return p
    }
}

nonisolated private struct GitBranchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        let r = min(w, h) * 0.12
        var p = Path()
        p.addEllipse(in: CGRect(x: x0 + w * 0.24 - r, y: y0 + h * 0.20 - r, width: r * 2, height: r * 2))
        p.addEllipse(in: CGRect(x: x0 + w * 0.24 - r, y: y0 + h * 0.80 - r, width: r * 2, height: r * 2))
        p.addEllipse(in: CGRect(x: x0 + w * 0.76 - r, y: y0 + h * 0.34 - r, width: r * 2, height: r * 2))
        p.move(to: CGPoint(x: x0 + w * 0.24, y: y0 + h * 0.32))
        p.addLine(to: CGPoint(x: x0 + w * 0.24, y: y0 + h * 0.68))
        p.move(to: CGPoint(x: x0 + w * 0.76, y: y0 + h * 0.46))
        p.addQuadCurve(to: CGPoint(x: x0 + w * 0.24, y: y0 + h * 0.68), control: CGPoint(x: x0 + w * 0.76, y: y0 + h * 0.68))
        return p
    }
}

nonisolated private struct OllamaSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        // Two ears + rounded head
        p.addRoundedRect(in: CGRect(x: x0 + w * 0.22, y: y0 + h * 0.08, width: w * 0.16, height: h * 0.36), cornerSize: CGSize(width: w * 0.08, height: w * 0.08))
        p.addRoundedRect(in: CGRect(x: x0 + w * 0.62, y: y0 + h * 0.08, width: w * 0.16, height: h * 0.36), cornerSize: CGSize(width: w * 0.08, height: w * 0.08))
        p.addRoundedRect(in: CGRect(x: x0 + w * 0.16, y: y0 + h * 0.32, width: w * 0.68, height: h * 0.58), cornerSize: CGSize(width: w * 0.28, height: w * 0.28))
        return p
    }
}

nonisolated private struct CoherePebblesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.addRoundedRect(in: CGRect(x: x0 + w * 0.10, y: y0 + h * 0.12, width: w * 0.62, height: h * 0.34), cornerSize: CGSize(width: h * 0.17, height: h * 0.17))
        p.addRoundedRect(in: CGRect(x: x0 + w * 0.28, y: y0 + h * 0.54, width: w * 0.62, height: h * 0.34), cornerSize: CGSize(width: h * 0.17, height: h * 0.17))
        return p
    }
}

nonisolated private struct MicrosoftGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        let gap = min(rect.width, rect.height) * 0.12
        let cell = (min(rect.width, rect.height) - gap) / 2.0
        let ox = rect.midX - cell - gap / 2.0
        let oy = rect.midY - cell - gap / 2.0
        var p = Path()
        for r in 0..<2 {
            for c in 0..<2 {
                p.addRect(CGRect(x: ox + CGFloat(c) * (cell + gap), y: oy + CGFloat(r) * (cell + gap), width: cell, height: cell))
            }
        }
        return p
    }
}

nonisolated private struct PerplexityPrismShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let r = min(rect.width, rect.height) * 0.44
        var p = Path()
        for i in 0..<4 {
            let angle = Double(i) * (.pi / 4.0)
            let dx = CGFloat(cos(angle)) * r
            let dy = CGFloat(sin(angle)) * r
            p.move(to: CGPoint(x: cx - dx, y: cy - dy))
            p.addLine(to: CGPoint(x: cx + dx, y: cy + dy))
        }
        return p
    }
}

nonisolated private struct BaiduPawShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.addEllipse(in: CGRect(x: x0 + w * 0.22, y: y0 + h * 0.48, width: w * 0.56, height: h * 0.42))
        let toes: [(CGFloat, CGFloat)] = [(0.16, 0.32), (0.37, 0.18), (0.63, 0.18), (0.84, 0.32)]
        let r = min(w, h) * 0.10
        for (tx, ty) in toes {
            p.addEllipse(in: CGRect(x: x0 + w * tx - r, y: y0 + h * ty - r, width: r * 2, height: r * 2))
        }
        return p
    }
}

nonisolated private struct XiaomiArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x0 + w * 0.14, y: y0 + h * 0.86))
        p.addLine(to: CGPoint(x: x0 + w * 0.14, y: y0 + h * 0.22))
        p.addLine(to: CGPoint(x: x0 + w * 0.62, y: y0 + h * 0.22))
        p.addQuadCurve(to: CGPoint(x: x0 + w * 0.72, y: y0 + h * 0.34), control: CGPoint(x: x0 + w * 0.72, y: y0 + h * 0.22))
        p.addLine(to: CGPoint(x: x0 + w * 0.72, y: y0 + h * 0.86))
        p.move(to: CGPoint(x: x0 + w * 0.43, y: y0 + h * 0.44))
        p.addLine(to: CGPoint(x: x0 + w * 0.43, y: y0 + h * 0.86))
        p.move(to: CGPoint(x: x0 + w * 0.90, y: y0 + h * 0.22))
        p.addLine(to: CGPoint(x: x0 + w * 0.90, y: y0 + h * 0.86))
        return p
    }
}

nonisolated private struct ZhipuZShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x0 + w * 0.16, y: y0 + h * 0.18))
        p.addLine(to: CGPoint(x: x0 + w * 0.84, y: y0 + h * 0.18))
        p.addLine(to: CGPoint(x: x0 + w * 0.16, y: y0 + h * 0.82))
        p.addLine(to: CGPoint(x: x0 + w * 0.84, y: y0 + h * 0.82))
        return p
    }
}

nonisolated private struct MiniMaxBarsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let x0 = rect.minX, y0 = rect.minY
        let barW = w * 0.20
        let heights: [CGFloat] = [0.46, 0.84, 0.62]
        let xs: [CGFloat] = [0.12, 0.40, 0.68]
        var p = Path()
        for (x, bh) in zip(xs, heights) {
            let bhPx = h * bh
            p.addRoundedRect(
                in: CGRect(x: x0 + w * x, y: y0 + (h - bhPx) / 2, width: barW, height: bhPx),
                cornerSize: CGSize(width: barW / 2, height: barW / 2)
            )
        }
        return p
    }
}

nonisolated private struct StepFunShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = min(rect.width, rect.height) / 3.0
        let ox = rect.midX - u * 1.5
        let oy = rect.midY - u * 1.5
        var p = Path()
        p.addRect(CGRect(x: ox, y: oy + u * 2, width: u, height: u))
        p.addRect(CGRect(x: ox + u, y: oy + u, width: u, height: u * 2))
        p.addRect(CGRect(x: ox + u * 2, y: oy, width: u, height: u * 3))
        return p
    }
}
