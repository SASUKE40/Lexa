import Foundation
import Testing
@testable import Lexa

struct CLIArgumentsTests {
    @Test func claudeRunsWithoutToolsOrSessions() {
        let args = ClaudeCodeBackend.arguments(system: "RULES", model: "haiku")
        #expect(args.first == "-p")
        #expect(pair(args, "--tools") == "")
        #expect(pair(args, "--system-prompt") == "RULES")
        #expect(pair(args, "--output-format") == "stream-json")
        #expect(pair(args, "--model") == "haiku")
        #expect(args.contains("--no-session-persistence"))
        #expect(args.contains("--strict-mcp-config"))
        #expect(!args.contains("--bare"))
    }

    @Test func claudeOmitsModelWhenEmpty() {
        #expect(!ClaudeCodeBackend.arguments(system: "x", model: "").contains("--model"))
    }

    @Test func codexRunsReadOnlyAndReadsPromptFromStdin() {
        let args = CodexBackend.arguments(model: "gpt-5.4-mini", workspace: "/tmp/w")
        #expect(args.first == "exec")
        #expect(args.last == "-")
        #expect(pair(args, "--sandbox") == "read-only")
        #expect(pair(args, "-C") == "/tmp/w")
        #expect(pair(args, "-m") == "gpt-5.4-mini")
        #expect(args.contains("--json"))
        #expect(args.contains("--ephemeral"))
        #expect(args.contains("approval_policy=\"never\""))
        #expect(!args.contains { $0.contains("dangerously") })
    }

    @Test func codexOmitsModelWhenEmpty() {
        #expect(!CodexBackend.arguments(model: "", workspace: "/tmp").contains("-m"))
    }

    @Test func userTextGoesThroughStdinNotArguments() {
        let request = PromptBuilder.request(action: .fix, text: "secret draft", model: "m")
        #expect(!ClaudeCodeBackend.arguments(system: request.system, model: request.model).joined().contains("secret draft"))
        #expect(CodexBackend.prompt(request).contains("<text>\nsecret draft\n</text>"))
    }

    @Test func friendlyErrorsPointToSignIn() {
        #expect(ClaudeCodeBackend.friendly("Invalid API key · Please run /login") == ClaudeCodeBackend.signInMessage)
        #expect(CodexBackend.friendly("Not logged in") == CodexBackend.signInMessage)
        #expect(CodexBackend.friendly("model is not supported").contains("not supported"))
    }

    private func pair(_ args: [String], _ flag: String) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
}

struct CLIRunnerTests {
    @Test func streamsStdoutAndPassesStdin() async throws {
        let cat = URL(fileURLWithPath: "/bin/cat")
        var lines: [String] = []
        for try await line in CLIRunner.lines(cat, [], stdin: "one\ntwo\n") { lines.append(line) }
        #expect(lines == ["one", "two"])
    }

    @Test func nonZeroExitThrowsWithStderr() async {
        let sh = URL(fileURLWithPath: "/bin/sh")
        await #expect(throws: CLIProcessError.self) {
            for try await _ in CLIRunner.lines(sh, ["-c", "echo oops >&2; exit 3"]) {}
        }
        let result = try? await CLIRunner.run(sh, ["-c", "echo oops >&2; exit 3"])
        #expect(result?.status == 3)
        #expect(result?.stderr.contains("oops") == true)
    }

    @Test func timeoutTerminatesProcess() async {
        let start = Date()
        await #expect(throws: LLMError.self) {
            _ = try await CLIRunner.run(URL(fileURLWithPath: "/bin/sleep"), ["30"], timeout: .milliseconds(300))
        }
        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test func cancellationTerminatesProcess() async {
        let start = Date()
        let task = Task {
            try await CLIRunner.run(URL(fileURLWithPath: "/bin/sleep"), ["30"])
        }
        try? await Task.sleep(for: .milliseconds(200))
        task.cancel()
        _ = await task.result
        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test func locatesSystemBinaries() async {
        #expect(await CLILocator.locate("sh")?.path.hasSuffix("/sh") == true)
        #expect(await CLILocator.locate("definitely-not-a-real-binary-lexa") == nil)
        #expect(await CLILocator.locate("x", override: "/bin/sh")?.path == "/bin/sh")
        #expect(await CLILocator.locate("x", override: "/nope/missing") == nil)
    }
}
