import Foundation
import Testing
@testable import Lexa

struct PKCETests {
    @Test func challengeMatchesRFC7636Example() {
        #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func verifiersAreRandomAndURLSafe() {
        let a = PKCE.makeVerifier()
        let b = PKCE.makeVerifier()
        #expect(a != b)
        #expect(a.count == 43)
        #expect(a.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }
}

struct DeviceFlowTests {
    @Test func parsesNousDeviceAuthorization() throws {
        let body = Data(#"{"device_code":"dev","user_code":"W8PY-PS2Y","verification_uri":"https://portal.nousresearch.com/manage-subscription","verification_uri_complete":"https://portal.nousresearch.com/manage-subscription?user_code=W8PY-PS2Y","expires_in":600,"interval":5}"#.utf8)
        let auth = try DeviceAuthorization.parse(body)
        #expect(auth.deviceCode == "dev")
        #expect(auth.userCode == "W8PY-PS2Y")
        #expect(auth.verificationURLComplete?.absoluteString.hasSuffix("user_code=W8PY-PS2Y") == true)
        #expect(auth.expiresIn == 600)
        #expect(auth.interval == 5)
    }

    @Test func parsesGitHubDeviceAuthorizationWithoutCompleteURL() throws {
        let body = Data(#"{"device_code":"d","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":899,"interval":5}"#.utf8)
        let auth = try DeviceAuthorization.parse(body)
        #expect(auth.verificationURL.absoluteString == "https://github.com/login/device")
        #expect(auth.verificationURLComplete == nil)
    }

    @Test func rejectsErrorResponses() {
        #expect(throws: LLMError.self) {
            try DeviceAuthorization.parse(Data(#"{"error":"invalid_client"}"#.utf8))
        }
    }

    @Test func classifiesPollResponses() {
        #expect(DeviceFlow.classify(status: 400, body: Data(#"{"error":"authorization_pending"}"#.utf8)) == .pending)
        #expect(DeviceFlow.classify(status: 200, body: Data(#"{"error":"authorization_pending"}"#.utf8)) == .pending)
        #expect(DeviceFlow.classify(status: 400, body: Data(#"{"error":"slow_down"}"#.utf8)) == .slowDown)
        #expect(DeviceFlow.classify(status: 400, body: Data(#"{"error":"access_denied"}"#.utf8)) == .denied)
        #expect(DeviceFlow.classify(status: 400, body: Data(#"{"error":"expired_token"}"#.utf8)) == .expired)
        #expect(DeviceFlow.classify(status: 400, body: Data(#"{"error":"bad","error_description":"Bad request"}"#.utf8)) == .failure("Bad request"))
        #expect(DeviceFlow.classify(status: 500, body: Data("oops".utf8)) == .failure("The sign-in server sent HTTP error 500."))
    }

    @Test func classifiesSuccessWithExpiry() {
        let now = Date(timeIntervalSince1970: 1_000)
        let result = DeviceFlow.classify(status: 200, body: Data(#"{"access_token":"a","refresh_token":"r","expires_in":3600}"#.utf8), now: now)
        #expect(result == .success(OAuthTokens(accessToken: "a", refreshToken: "r", expiresAt: now.addingTimeInterval(3600))))
    }

    @Test func encodesFormFields() {
        #expect(DeviceFlow.encode(["scope": "inference:invoke", "client_id": "hermes-cli"]) == "client_id=hermes-cli&scope=inference%3Ainvoke")
    }
}

struct OAuthTokensTests {
    @Test func refreshesTwoMinutesBeforeExpiry() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(!OAuthTokens(accessToken: "a", expiresAt: now.addingTimeInterval(121)).needsRefresh(now: now))
        #expect(OAuthTokens(accessToken: "a", expiresAt: now.addingTimeInterval(120)).needsRefresh(now: now))
        #expect(OAuthTokens(accessToken: "a", expiresAt: now.addingTimeInterval(-1)).needsRefresh(now: now))
        #expect(!OAuthTokens(accessToken: "a", expiresAt: nil).needsRefresh(now: now))
    }

    @Test func roundTripsThroughJSON() throws {
        let tokens = OAuthTokens(accessToken: "a", refreshToken: "r", expiresAt: Date(timeIntervalSince1970: 1_234))
        let decoded = try JSONDecoder().decode(OAuthTokens.self, from: JSONEncoder().encode(tokens))
        #expect(decoded == tokens)
    }
}

struct OpenRouterOAuthTests {
    @Test func authorizationURLCarriesPKCEAndState() throws {
        let url = OpenRouterOAuth.authorizationURL(callback: "http://localhost:51423/callback", challenge: "CH", state: "ST")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(url.host == "openrouter.ai")
        #expect(query["callback_url"] == "http://localhost:51423/callback")
        #expect(query["code_challenge"] == "CH")
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["state"] == "ST")
        #expect(query["key_label"] == "Lexa")
    }
}

struct LoopbackServerTests {
    @Test func parsesCallbackRequests() {
        let request = "GET /callback?code=abc%20d&state=xyz HTTP/1.1\r\nHost: localhost:5000\r\n\r\n"
        #expect(LoopbackServer.query(fromRequest: request, path: "/callback") == ["code": "abc d", "state": "xyz"])
        #expect(LoopbackServer.query(fromRequest: "GET /favicon.ico HTTP/1.1\r\n\r\n", path: "/callback") == nil)
        #expect(LoopbackServer.query(fromRequest: "POST /callback?code=a HTTP/1.1\r\n\r\n", path: "/callback") == nil)
    }

    @Test func receivesARealRedirect() async throws {
        let server = try LoopbackServer()
        defer { server.stop() }
        let port = try await server.start()
        #expect(port > 0)

        async let callback = server.waitForCallback(timeout: .seconds(10))
        let (_, response) = try await URLSession.shared.data(from: URL(string: "http://localhost:\(port)/callback?code=c123&state=s456")!)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(try await callback == ["code": "c123", "state": "s456"])
    }

    @Test func timesOut() async throws {
        let server = try LoopbackServer()
        defer { server.stop() }
        _ = try await server.start()
        await #expect(throws: LLMError.self) {
            _ = try await server.waitForCallback(timeout: .milliseconds(200))
        }
    }
}
