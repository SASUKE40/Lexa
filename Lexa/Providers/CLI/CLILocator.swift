import Foundation

/// Finds CLI binaries. GUI apps don't inherit the shell PATH, so we check common install
/// locations and finally ask a login shell.
nonisolated enum CLILocator {
    static var searchDirectories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.claude/local",
            "\(home)/.npm-global/bin",
            "\(home)/.bun/bin",
            "\(home)/.volta/bin",
            "\(home)/.cargo/bin",
            "/usr/bin",
            "/bin",
        ]
    }

    /// Empty scratch directory used as the working directory for CLI runs.
    static var workspace: URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "Lexa-workspace", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// PATH for child processes: the binary's folder, common folders, then the inherited PATH.
    static func environmentPATH(including directory: String? = nil) -> String {
        var parts = [directory].compactMap { $0 } + searchDirectories
        parts += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        parts += ["/usr/sbin", "/sbin"]
        var seen = Set<String>()
        return parts.filter { !$0.isEmpty && seen.insert($0).inserted }.joined(separator: ":")
    }

    static func locate(_ name: String, override: String = "") async -> URL? {
        let fm = FileManager.default
        let custom = (override as NSString).expandingTildeInPath.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty {
            return fm.isExecutableFile(atPath: custom) ? URL(fileURLWithPath: custom) : nil
        }
        for directory in searchDirectories {
            let path = "\(directory)/\(name)"
            if fm.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
        }
        let shell = URL(fileURLWithPath: "/bin/zsh")
        guard let result = try? await CLIRunner.run(shell, ["-lc", "command -v \(name)"], timeout: .seconds(5)),
              result.status == 0
        else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").last ?? ""
        return path.hasPrefix("/") && fm.isExecutableFile(atPath: path) ? URL(fileURLWithPath: path) : nil
    }
}
