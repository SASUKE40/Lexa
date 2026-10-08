import Foundation

/// GitHub Models sign-in: device authorization with the Lexa OAuth App, or the GitHub CLI token.
nonisolated enum GitHubOAuth {
    /// Client ID of the Lexa GitHub OAuth App (device flow on). Empty means "not set up".
    static let clientID = "Ov23liaOJflq8bCRpSDy"
    static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    static let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    static var isConfigured: Bool { !clientID.isEmpty }

    static func startSignIn() async throws -> DeviceAuthorization {
        try await DeviceFlow.requestAuthorization(url: deviceCodeURL, form: ["client_id": clientID])
    }

    static func completeSignIn(_ authorization: DeviceAuthorization) async throws -> String {
        try await DeviceFlow.pollForTokens(url: tokenURL, form: ["client_id": clientID], authorization: authorization).accessToken
    }

    /// `gh auth token` is the official way to give the GitHub CLI login to other tools.
    static func tokenFromCLI() async throws -> String {
        guard let gh = await CLILocator.locate("gh") else {
            throw LLMError("Lexa cannot find the GitHub CLI (gh). Install it from cli.github.com.")
        }
        let result = try await CLIRunner.run(gh, ["auth", "token"], timeout: .seconds(20))
        let token = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.status == 0, !token.isEmpty else {
            throw LLMError("The GitHub CLI is not signed in. In Terminal, type this command: gh auth login")
        }
        return token
    }
}
