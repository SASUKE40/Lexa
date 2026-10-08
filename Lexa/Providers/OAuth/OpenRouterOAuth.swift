import Foundation

/// "Sign in with OpenRouter": the official OAuth PKCE flow, which gives a normal API key.
/// https://openrouter.ai/docs/use-cases/oauth-pkce
nonisolated enum OpenRouterOAuth {
    static let exchangeURL = URL(string: "https://openrouter.ai/api/v1/auth/keys")!

    static func authorizationURL(callback: String, challenge: String, state: String) -> URL {
        var components = URLComponents(string: "https://openrouter.ai/auth")!
        components.queryItems = [
            URLQueryItem(name: "callback_url", value: callback),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "key_label", value: "Lexa"),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    /// Opens the browser, waits for the redirect to a loopback port, and returns the new API key.
    static func signIn(open: @escaping @MainActor @Sendable (URL) -> Void) async throws -> String {
        let server = try LoopbackServer()
        defer { server.stop() }
        let port = try await server.start()
        let verifier = PKCE.makeVerifier()
        let state = PKCE.makeVerifier()
        let url = authorizationURL(callback: "http://localhost:\(port)\(server.path)",
                                   challenge: PKCE.challenge(for: verifier), state: state)
        await open(url)

        let query = try await server.waitForCallback(timeout: .seconds(300))
        if query["error"] != nil { throw LLMError("You did not give access.") }
        guard query["state"] == state else { throw LLMError("The sign-in result is not correct. Try again.") }
        guard let code = query["code"], !code.isEmpty else { throw LLMError("OpenRouter did not send an access code.") }
        return try await exchange(code: code, verifier: verifier)
    }

    static func exchange(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: exchangeURL, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "code": code,
            "code_verifier": verifier,
            "code_challenge_method": "S256",
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status),
              let key = JSONLine.object(String(decoding: data, as: UTF8.self))?["key"] as? String, !key.isEmpty
        else {
            throw LLMError(JSONLine.errorMessage(data) ?? "OpenRouter sent HTTP error \(status).")
        }
        return key
    }
}
