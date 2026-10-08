import Foundation

/// "Sign in with Nous Portal": device authorization that gives an inference token for the
/// Nous Portal subscription. Nous has no public client registration, so this uses the public
/// client ID of Hermes Agent (the Nous Research CLI). Nous can stop this at any time.
nonisolated enum NousOAuth {
    static let clientID = "hermes-cli"
    static let scope = "inference:invoke"
    static let deviceCodeURL = URL(string: "https://portal.nousresearch.com/api/oauth/device/code")!
    static let tokenURL = URL(string: "https://portal.nousresearch.com/api/oauth/token")!
    static let keychainAccount = "nous.oauth"

    static var isSignedIn: Bool { Keychain.read(keychainAccount) != nil }

    static func startSignIn() async throws -> DeviceAuthorization {
        try await DeviceFlow.requestAuthorization(url: deviceCodeURL, form: ["client_id": clientID, "scope": scope])
    }

    static func completeSignIn(_ authorization: DeviceAuthorization) async throws {
        let tokens = try await DeviceFlow.pollForTokens(url: tokenURL, form: ["client_id": clientID], authorization: authorization)
        await NousSession.shared.save(tokens)
    }

    static func signOut() async {
        await NousSession.shared.save(nil)
    }
}

/// Keeps the Nous tokens in the Keychain and refreshes the access token before it expires.
/// Nous refresh tokens are single-use, so only one refresh can run at a time.
actor NousSession {
    static let shared = NousSession()
    static let signInMessage = "Sign in to Nous Portal in Settings, or add an API key."
    static let expiredMessage = "Your Nous Portal session ended. Sign in again in Settings."

    private var refreshTask: Task<OAuthTokens, Error>?

    func save(_ tokens: OAuthTokens?) {
        let json = tokens.flatMap { try? JSONEncoder().encode($0) }.map { String(decoding: $0, as: UTF8.self) }
        Keychain.save(json ?? "", for: NousOAuth.keychainAccount)
    }

    func accessToken() async throws -> String {
        guard let tokens = load() else { throw LLMError(Self.signInMessage) }
        guard tokens.needsRefresh() else { return tokens.accessToken }
        if let refreshTask { return try await refreshTask.value.accessToken }
        guard let refreshToken = tokens.refreshToken else {
            save(nil)
            throw LLMError(Self.expiredMessage)
        }

        let task = Task { try await Self.refresh(refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            var fresh = try await task.value
            if fresh.refreshToken == nil { fresh.refreshToken = refreshToken }
            save(fresh)
            return fresh.accessToken
        } catch let error as RefreshRejected {
            save(nil)
            throw LLMError(error.message)
        }
    }

    private func load() -> OAuthTokens? {
        Keychain.read(NousOAuth.keychainAccount).flatMap { try? JSONDecoder().decode(OAuthTokens.self, from: Data($0.utf8)) }
    }

    private struct RefreshRejected: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static func refresh(_ refreshToken: String) async throws -> OAuthTokens {
        let (status, data) = try await DeviceFlow.post(
            url: NousOAuth.tokenURL,
            form: ["grant_type": "refresh_token", "client_id": NousOAuth.clientID, "refresh_token": refreshToken],
            headers: ["x-nous-refresh-token": refreshToken]
        )
        if (200..<300).contains(status), let object = JSONLine.object(String(decoding: data, as: UTF8.self)),
           let tokens = OAuthTokens.parse(object) {
            return tokens
        }
        if (400..<500).contains(status) { throw RefreshRejected(message: expiredMessage) }
        throw LLMError(JSONLine.errorMessage(data) ?? "Nous Portal sent HTTP error \(status).")
    }
}
