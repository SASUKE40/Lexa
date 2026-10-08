import Foundation

/// Uses the user's own signed-in Codex CLI (`codex exec`). Lexa never touches its credentials.
nonisolated struct CodexBackend: LLMBackend {
    let model: String
    let pathOverride: String

    static let missingMessage = "Lexa cannot find the Codex CLI. Install it from developers.openai.com/codex/cli. Or select its path in Settings."
    static let signInMessage = "Codex is not signed in. In Terminal, type this command: codex login"

    static func arguments(model: String, workspace: String) -> [String] {
        var arguments = [
            "exec",
            "--json",
            "--ephemeral",
            "--skip-git-repo-check",
            "--ignore-user-config",
            "--ignore-rules",
            "--sandbox", "read-only",
            "--color", "never",
            "-C", workspace,
            "-c", "approval_policy=\"never\"",
            "-c", "model_reasoning_effort=\"low\"",
        ]
        if !model.isEmpty { arguments += ["-m", model] }
        arguments.append("-")
        return arguments
    }

    static func prompt(_ request: LLMRequest) -> String {
        request.system + "\n\n" + request.user
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<TextUpdate, Error> {
        Self.makeStream { continuation in
            guard let executable = await CLILocator.locate("codex", override: pathOverride) else {
                throw LLMError(Self.missingMessage)
            }
            let workspace = CLILocator.workspace
            let lines = CLIRunner.lines(executable, Self.arguments(model: request.model, workspace: workspace.path),
                                        stdin: Self.prompt(request), workingDirectory: workspace)
            var lastError: String?
            var gotText = false
            do {
                for try await line in lines {
                    switch CodexStreamParser.parse(line: line) {
                    case .delta(let text):
                        continuation.yield(.append(text))
                        gotText = true
                    case .snapshot(let text), .final(let text):
                        continuation.yield(.replace(text))
                        gotText = true
                    case .error(let message): lastError = message
                    case .done, .ignore: continue
                    }
                }
            } catch let error as CLIProcessError {
                throw LLMError(Self.friendly(lastError ?? error.result.diagnostics))
            }
            if !gotText, let lastError { throw LLMError(Self.friendly(lastError)) }
        }
    }

    func test() async -> BackendStatus {
        guard let executable = await CLILocator.locate("codex", override: pathOverride) else {
            return .problem(Self.missingMessage)
        }
        do {
            let status = try await CLIRunner.run(executable, ["login", "status"], timeout: .seconds(20))
            guard status.status == 0 else { return .problem(Self.signInMessage) }
            let elapsed = try await ping(model: model)
            return .ready("Signed in. Time: \(elapsed).")
        } catch {
            return .problem(error.localizedDescription)
        }
    }

    func listModels() async throws -> [String] {
        Provider.codex.suggestedModels
    }

    static func friendly(_ message: String) -> String {
        let lower = message.lowercased()
        if ["not logged in", "login", "log in", "unauthorized", "401"].contains(where: lower.contains) {
            return signInMessage
        }
        if lower.contains("usage limit") || lower.contains("rate limit") || lower.contains("429") {
            return "You are at the Codex usage limit of your ChatGPT plan. \(message.prefix(200))"
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Codex stopped, but it did not send an error message." : String(trimmed.suffix(400))
    }
}
