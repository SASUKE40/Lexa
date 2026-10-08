import Foundation

/// The latest GitHub release of Lexa, from `GET /repos/SASUKE40/Lexa/releases/latest`.
nonisolated struct ReleaseInfo: Sendable, Equatable {
    let version: SemanticVersion
    let tag: String
    let pageURL: URL
    let zipURL: URL?
    let checksumURL: URL?

    static let apiURL = URL(string: "https://api.github.com/repos/SASUKE40/Lexa/releases/latest")!
    static let releasesPage = URL(string: "https://github.com/SASUKE40/Lexa/releases/latest")!

    static func parse(_ data: Data) throws -> ReleaseInfo {
        guard let object = JSONLine.object(String(decoding: data, as: UTF8.self)),
              let tag = object["tag_name"] as? String,
              let version = SemanticVersion(tag)
        else { throw LLMError("GitHub sent release information that Lexa cannot read.") }

        let assets = (object["assets"] as? [[String: Any]] ?? []).compactMap { asset -> (name: String, url: URL)? in
            guard let name = asset["name"] as? String,
                  let url = (asset["browser_download_url"] as? String).flatMap(URL.init(string:))
            else { return nil }
            return (name, url)
        }
        let zipName = "Lexa-\(version).zip"
        return ReleaseInfo(
            version: version,
            tag: tag,
            pageURL: (object["html_url"] as? String).flatMap(URL.init(string:)) ?? releasesPage,
            zipURL: assets.first { $0.name == zipName }?.url,
            checksumURL: assets.first { $0.name == zipName + ".sha256" }?.url
        )
    }

    static func fetchLatest() async throws -> ReleaseInfo {
        var request = URLRequest(url: apiURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Lexa/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError("Lexa cannot connect to GitHub.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw LLMError(JSONLine.errorMessage(data) ?? "GitHub sent HTTP error \(status).")
        }
        return try parse(data)
    }
}
