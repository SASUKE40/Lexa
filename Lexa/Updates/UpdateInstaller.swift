import CryptoKit
import Foundation
import Security

/// Downloads a release, verifies it, and replaces the running app.
/// The new app must have the same designated requirement (bundle ID and signing certificate)
/// as the running app, so a changed or foreign build cannot install itself.
nonisolated enum UpdateInstaller {
    static let caskroomPaths = ["/opt/homebrew/Caskroom/lexa", "/usr/local/Caskroom/lexa"]
    static let brewCommand = "brew upgrade --cask lexa"

    static var isHomebrewInstall: Bool {
        caskroomPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Downloads and verifies the update. Returns the new `Lexa.app` in a temporary folder.
    static func prepare(_ release: ReleaseInfo) async throws -> URL {
        guard let zipURL = release.zipURL, let checksumURL = release.checksumURL else {
            throw LLMError("Lexa cannot find a download for this release.")
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: "Lexa-update-\(release.version)", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let zip = folder.appending(path: "Lexa.zip")
        let (downloaded, _) = try await URLSession.shared.download(from: zipURL)
        try FileManager.default.moveItem(at: downloaded, to: zip)
        let (checksumData, _) = try await URLSession.shared.data(from: checksumURL)

        guard let expected = parseChecksum(String(decoding: checksumData, as: UTF8.self)),
              try sha256(of: zip) == expected
        else { throw LLMError("The SHA-256 of the download is not correct.") }

        let result = try await CLIRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), ["-x", "-k", zip.path, folder.path])
        let app = folder.appending(path: "Lexa.app", directoryHint: .isDirectory)
        guard result.status == 0, FileManager.default.fileExists(atPath: app.path) else {
            throw LLMError("Lexa cannot open the downloaded file.")
        }

        let info = Bundle(url: app)?.infoDictionary ?? [:]
        guard info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              (info["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init) == release.version
        else { throw LLMError("The downloaded app is not the correct version of Lexa.") }

        guard hasSameSignature(app) else {
            throw LLMError("The update has a different code signature. Download it from the release page.")
        }
        return app
    }

    /// Replaces the running app with `newApp` after Lexa quits, then opens it again.
    static func replaceAndRelaunch(with newApp: URL) throws {
        let current = Bundle.main.bundleURL
        let folder = current.deletingLastPathComponent()
        guard !current.path.contains("/AppTranslocation/"),
              FileManager.default.isWritableFile(atPath: folder.path)
        else { throw LLMError("Lexa cannot replace the app in this folder. Download the update from the release page.") }

        // Positional arguments ($1…$3) keep the paths out of the script text.
        let script = """
            while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
            rm -rf "$2.previous"
            if mv "$2" "$2.previous" && mv "$3" "$2"; then rm -rf "$2.previous"
            elif [ -d "$2.previous" ] && [ ! -d "$2" ]; then mv "$2.previous" "$2"; fi
            open "$2"
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "lexa-update", String(ProcessInfo.processInfo.processIdentifier), current.path, newApp.path]
        try process.run()
    }

    static func parseChecksum(_ text: String) -> String? {
        let first = text.split(whereSeparator: \.isWhitespace).first.map { String($0).lowercased() } ?? ""
        return first.count == 64 && first.allSatisfy(\.isHexDigit) ? first : nil
    }

    static func sha256(of file: URL) throws -> String {
        let digest = SHA256.hash(data: try Data(contentsOf: file, options: .mappedIfSafe))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// True when `app` satisfies the designated requirement of the running app.
    static func hasSameSignature(_ app: URL) -> Bool {
        var running: SecCode?
        var runningStatic: SecStaticCode?
        var requirement: SecRequirement?
        var candidate: SecStaticCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running,
              SecCodeCopyStaticCode(running, [], &runningStatic) == errSecSuccess, let runningStatic,
              SecCodeCopyDesignatedRequirement(runningStatic, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess, let candidate
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(candidate, flags, requirement) == errSecSuccess
    }
}
