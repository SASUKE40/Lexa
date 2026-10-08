import Foundation

nonisolated struct DeviceAuthorization: Sendable, Equatable {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    /// Verification page with the code already filled in, if the server gives one.
    let verificationURLComplete: URL?
    let expiresIn: Int
    let interval: Int

    static func parse(_ data: Data) throws -> DeviceAuthorization {
        guard let object = JSONLine.object(String(decoding: data, as: UTF8.self)) else {
            throw LLMError("The sign-in server sent a result that Lexa cannot read.")
        }
        if let message = JSONLine.errorMessage(object) { throw LLMError(message) }
        guard let deviceCode = object["device_code"] as? String,
              let userCode = object["user_code"] as? String,
              let uri = (object["verification_uri"] as? String).flatMap(URL.init(string:))
        else { throw LLMError("The sign-in server sent a result that Lexa cannot read.") }
        return DeviceAuthorization(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURL: uri,
            verificationURLComplete: (object["verification_uri_complete"] as? String).flatMap(URL.init(string:)),
            expiresIn: (object["expires_in"] as? Int) ?? 900,
            interval: (object["interval"] as? Int) ?? 5
        )
    }
}

nonisolated struct OAuthTokens: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?

    static func parse(_ object: [String: Any], now: Date = Date()) -> OAuthTokens? {
        guard let access = object["access_token"] as? String, !access.isEmpty else { return nil }
        let expiresIn = (object["expires_in"] as? Double) ?? (object["expires_in"] as? Int).map(Double.init)
        return OAuthTokens(
            accessToken: access,
            refreshToken: object["refresh_token"] as? String,
            expiresAt: expiresIn.map { now.addingTimeInterval($0) }
        )
    }

    func needsRefresh(now: Date = Date(), margin: TimeInterval = 120) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) <= margin
    }
}

nonisolated enum DevicePollResult: Equatable {
    case pending
    case slowDown
    case success(OAuthTokens)
    case denied
    case expired
    case failure(String)
}

/// OAuth 2.0 Device Authorization Grant (RFC 8628).
nonisolated enum DeviceFlow {
    static let grantType = "urn:ietf:params:oauth:grant-type:device_code"

    static func requestAuthorization(url: URL, form: [String: String]) async throws -> DeviceAuthorization {
        let (status, data) = try await post(url: url, form: form)
        guard (200..<300).contains(status) else {
            throw LLMError(JSONLine.errorMessage(data) ?? "The sign-in server sent HTTP error \(status).")
        }
        return try DeviceAuthorization.parse(data)
    }

    static func pollForTokens(url: URL, form: [String: String], authorization: DeviceAuthorization) async throws -> OAuthTokens {
        var interval = max(authorization.interval, 1)
        let deadline = Date().addingTimeInterval(TimeInterval(authorization.expiresIn))
        var fields = form
        fields["device_code"] = authorization.deviceCode
        fields["grant_type"] = grantType
        while Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            let (status, data) = try await post(url: url, form: fields)
            switch classify(status: status, body: data) {
            case .pending: continue
            case .slowDown: interval += 5
            case .success(let tokens): return tokens
            case .denied: throw LLMError("You did not give access.")
            case .expired: throw LLMError("The code expired. Try again.")
            case .failure(let message): throw LLMError(message)
            }
        }
        throw LLMError("The code expired. Try again.")
    }

    /// GitHub sends pending errors with HTTP 200, so the `error` field wins over the status code.
    static func classify(status: Int, body: Data, now: Date = Date()) -> DevicePollResult {
        let object = JSONLine.object(String(decoding: body, as: UTF8.self)) ?? [:]
        if let error = object["error"] as? String {
            switch error {
            case "authorization_pending": return .pending
            case "slow_down": return .slowDown
            case "access_denied": return .denied
            case "expired_token": return .expired
            default: return .failure((object["error_description"] as? String) ?? error)
            }
        }
        guard (200..<300).contains(status), let tokens = OAuthTokens.parse(object, now: now) else {
            return .failure("The sign-in server sent HTTP error \(status).")
        }
        return .success(tokens)
    }

    static func post(url: URL, form: [String: String], headers: [String: String] = [:]) async throws -> (Int, Data) {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = Data(encode(form).utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    }

    static func encode(_ form: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return form.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
    }
}
