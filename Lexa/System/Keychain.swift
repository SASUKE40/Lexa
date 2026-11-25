import Foundation
import os

/// Stores API keys and OAuth tokens in an owner-only (`0600`) file inside Application Support,
/// so opening Settings, rebuilding, and updating never trigger macOS login-keychain password prompts.
nonisolated enum Keychain {
    private static let lock = OSAllocatedUnfairLock()

    private static var defaultStoreURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return appSupport.appending(path: "Lexa/secrets.json")
    }

    static func read(_ account: String) -> String? {
        readLocal(account, from: defaultStoreURL)
    }

    static func save(_ value: String, for account: String) {
        saveLocal(value, for: account, to: defaultStoreURL)
    }

    // MARK: - Local 0600 store (internal for tests)

    static func readLocal(_ account: String, from url: URL) -> String? {
        lock.withLock {
            loadSecrets(from: url)[account]
        }
    }

    static func saveLocal(_ value: String, for account: String, to url: URL) {
        lock.withLock {
            var secrets = loadSecrets(from: url)
            if value.isEmpty {
                secrets.removeValue(forKey: account)
            } else {
                secrets[account] = value
            }
            writeSecrets(secrets, to: url)
        }
    }

    private static func loadSecrets(from url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func writeSecrets(_ secrets: [String: String], to url: URL) {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)

        guard let data = try? JSONEncoder().encode(secrets) else { return }
        let tempURL = dir.appending(path: ".secrets.\(UUID().uuidString).tmp")
        guard fm.createFile(atPath: tempURL.path, contents: data, attributes: [.posixPermissions: 0o600]) else { return }
        do {
            _ = try fm.replaceItemAt(url, withItemAt: tempURL)
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            try? fm.removeItem(at: tempURL)
        }
    }
}
