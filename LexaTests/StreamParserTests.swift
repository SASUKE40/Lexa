import Foundation
import Testing
@testable import Lexa

struct OpenAIStreamParserTests {
    @Test func parsesDeltas() {
        let line = #"data: {"id":"1","choices":[{"index":0,"delta":{"content":"Hel"}}]}"#
        #expect(OpenAIStreamParser.parse(line: line) == .delta("Hel"))
    }

    @Test func ignoresRoleOnlyAndReasoningDeltas() {
        #expect(OpenAIStreamParser.parse(line: #"data: {"choices":[{"delta":{"role":"assistant","content":""}}]}"#) == .ignore)
        #expect(OpenAIStreamParser.parse(line: #"data: {"choices":[{"delta":{"reasoning":"hmm"}}]}"#) == .ignore)
    }

    @Test func handlesDoneCommentsAndBlankLines() {
        #expect(OpenAIStreamParser.parse(line: "data: [DONE]") == .done)
        #expect(OpenAIStreamParser.parse(line: ": OPENROUTER PROCESSING") == .ignore)
        #expect(OpenAIStreamParser.parse(line: "") == .ignore)
        #expect(OpenAIStreamParser.parse(line: "event: message") == .ignore)
    }

    @Test func surfacesMidStreamErrors() {
        let line = #"data: {"error":{"message":"Rate limit exceeded","code":429}}"#
        #expect(OpenAIStreamParser.parse(line: line) == .error("Rate limit exceeded"))
    }

    @Test func parsesNonStreamingBody() {
        let body = Data(#"{"choices":[{"message":{"role":"assistant","content":"Fixed."}}]}"#.utf8)
        #expect(OpenAIStreamParser.parse(body: body) == .final("Fixed."))
    }

    @Test func extractsErrorsFromCommonShapes() {
        #expect(JSONLine.errorMessage(Data(#"{"error":{"message":"Invalid key"}}"#.utf8)) == "Invalid key")
        #expect(JSONLine.errorMessage(Data(#"[{"error":{"code":400,"message":"API key not valid"}}]"#.utf8)) == "API key not valid")
        #expect(JSONLine.errorMessage(Data(#"{"error":"model not found"}"#.utf8)) == "model not found")
        #expect(JSONLine.errorMessage(Data("<html>".utf8)) == nil)
    }
}

struct ClaudeStreamParserTests {
    @Test func parsesTextDeltas() {
        let line = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"They're"}},"session_id":"x"}"#
        #expect(ClaudeStreamParser.parse(line: line) == .delta("They're"))
    }

    @Test func ignoresThinkingAndSystemEvents() {
        let thinking = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"hmm"}}}"#
        #expect(ClaudeStreamParser.parse(line: thinking) == .ignore)
        #expect(ClaudeStreamParser.parse(line: #"{"type":"system","subtype":"init","model":"claude-haiku"}"#) == .ignore)
    }

    @Test func parsesAssistantSnapshot() {
        let line = #"{"type":"assistant","message":{"content":[{"type":"text","text":"Hello."}]}}"#
        #expect(ClaudeStreamParser.parse(line: line) == .snapshot("Hello."))
    }

    @Test func parsesResults() {
        #expect(ClaudeStreamParser.parse(line: #"{"type":"result","subtype":"success","is_error":false,"result":"Done."}"#) == .final("Done."))
        #expect(ClaudeStreamParser.parse(line: #"{"type":"result","subtype":"success","is_error":true,"result":"Not logged in"}"#) == .error("Not logged in"))
        #expect(ClaudeStreamParser.parse(line: #"{"type":"result","subtype":"error_max_turns","is_error":true}"#) == .error("error_max_turns"))
    }
}

/// Lines captured from real CLI runs (codex-cli 0.159.1, Claude Code 2.1.252).
struct RealCLIOutputTests {
    @Test func codexExecTranscript() {
        let transcript = [
            #"{"type":"thread.started","thread_id":"00000000-0000-0000-0000-000000000000"}"#,
            #"{"type":"turn.started"}"#,
            #"{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"They're going to the library tomorrow."}}"#,
            #"{"type":"turn.completed","usage":{"input_tokens":16345,"cached_input_tokens":7168,"cache_write_input_tokens":0,"output_tokens":11,"reasoning_output_tokens":0}}"#,
        ]
        #expect(transcript.map(CodexStreamParser.parse) == [.ignore, .ignore, .final("They're going to the library tomorrow."), .done])
    }

    @Test func claudeExpiredLoginIsAnErrorEvenWithSuccessSubtype() {
        let message = "Anthropic profile login expired · Run /login to use your claude.ai account instead, or re-authenticate the profile"
        let line = #"{"type":"result","subtype":"success","is_error":true,"terminal_reason":"api_error","result":"\#(message)"}"#
        #expect(ClaudeStreamParser.parse(line: line) == .error(message))
        #expect(ClaudeCodeBackend.friendly(message) == ClaudeCodeBackend.signInMessage)
    }
}

struct CodexStreamParserTests {
    @Test func parsesAgentMessages() {
        let line = #"{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"Fixed text."}}"#
        #expect(CodexStreamParser.parse(line: line) == .final("Fixed text."))
    }

    @Test func ignoresReasoningAndLifecycleEvents() {
        #expect(CodexStreamParser.parse(line: #"{"type":"item.completed","item":{"id":"item_0","type":"reasoning","text":"thinking"}}"#) == .ignore)
        #expect(CodexStreamParser.parse(line: #"{"type":"thread.started","thread_id":"abc"}"#) == .ignore)
        #expect(CodexStreamParser.parse(line: #"{"type":"turn.started"}"#) == .ignore)
        #expect(CodexStreamParser.parse(line: "not json") == .ignore)
    }

    @Test func parsesFailures() {
        #expect(CodexStreamParser.parse(line: #"{"type":"turn.failed","error":{"message":"usage limit reached"}}"#) == .error("usage limit reached"))
        #expect(CodexStreamParser.parse(line: #"{"type":"error","message":"stream disconnected"}"#) == .error("stream disconnected"))
        #expect(CodexStreamParser.parse(line: #"{"type":"turn.completed","usage":{}}"#) == .done)
    }
}
