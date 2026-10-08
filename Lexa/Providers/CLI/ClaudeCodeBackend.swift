import Foundation

/// Uses the user's own signed-in Claude Code CLI (`claude -p`). Lexa never touches its credentials.
nonisolated struct ClaudeCodeBackend: LLMBackend {
    let model: String
    let pathOverride: String

    static let missingMessage = "Lexa cannot find the Claude Code CLI. Install it from claude.com/product/claude-code. Or select its path in Settings."
    static let signInMessage = "Claude Code is not signed in. In Terminal, type this command: claude auth login"

    static func arguments(system: String, model: String) -> [String] {
        var arguments = [
            "-p",
            "--output-format", "stream-json",
            "--include-partial-messages",
            "--verbose",
            "--system-prompt", system,
            "--effort", "low",
            "--tools", "",
            "--strict-mcp-config",
            "--disable-slash-commands",
            "--no-session-persistence",
            "--setting-sources", "",
        ]
        if !model.isEmpty { arguments += ["--model", model] }
        return arguments
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<TextUpdate, Error> {
        Self.makeStream { continuation in
            guard let executable = await CLILocator.locate("claude", override: pathOverride) else {
                throw LLMError(Self.missingMessage)
            }
            let lines = CLIRunner.lines(executable, Self.arguments(system: request.system, model: request.model),
                                        stdin: request.user, workingDirectory: CLILocator.workspace)
            do {
                for try await line in lines {
                    switch ClaudeStreamParser.parse(line: line) {
                    case .delta(let text): continuation.yield(.append(text))
                    case .snapshot(let text), .final(let text): continuation.yield(.replace(text))
                    case .error(let message): throw LLMError(Self.friendly(message))
                    case .done, .ignore: continue
                    }
                }
            } catch let error as CLIProcessError {
                throw LLMError(Self.friendly(error.result.diagnostics))
            }
        }
    }

    func test() async -> BackendStatus {
        guard let executable = await CLILocator.locate("claude", override: pathOverride) else {
            return .problem(Self.missingMessage)
        }
        do {
            let status = try await CLIRunner.run(executable, ["auth", "status", "--json"], timeout: .seconds(20))
            let loggedIn = JSONLine.object(status.stdout)?["loggedIn"] as? Bool ?? false
            guard loggedIn else { return .problem(Self.signInMessage) }
            // `auth status` can report a login that has since expired, so make a real request.
            let elapsed = try await ping(model: model)
            return .ready("Signed in. Time: \(elapsed).")
        } catch {
            return .problem(error.localizedDescription)
        }
    }

    func listModels() async throws -> [String] {
        Provider.claude.suggestedModels
    }

    static func friendly(_ message: String) -> String {
        let lower = message.lowercased()
        if ["not logged in", "log in", "login", "authenticat", "unauthorized", "invalid api key", "oauth"].contains(where: lower.contains) {
            return signInMessage
        }
        if lower.contains("usage limit") || lower.contains("rate limit") {
            return "You are at the usage limit of your Claude plan. \(message.prefix(200))"
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Claude Code stopped, but it did not send an error message." : String(trimmed.suffix(400))
    }
}
