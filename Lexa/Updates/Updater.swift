import AppKit
import Observation

/// Finds new GitHub releases (on launch and every day) and installs them.
@Observable
final class Updater {
    enum Status: Equatable {
        case idle
        case finding
        case upToDate
        case available(ReleaseInfo)
        case installing(ReleaseInfo)
        case failed(String)
    }

    var status: Status = .idle
    var lastSearch: Date? {
        didSet { UserDefaults.standard.set(lastSearch, forKey: Self.lastSearchKey) }
    }

    @ObservationIgnored private var loop: Task<Void, Never>?
    private static let lastSearchKey = "lastUpdateSearch"
    private static let interval: TimeInterval = 24 * 60 * 60

    init() {
        lastSearch = UserDefaults.standard.object(forKey: Self.lastSearchKey) as? Date
    }

    var available: ReleaseInfo? {
        if case .available(let release) = status { return release }
        return nil
    }

    var isHomebrewInstall: Bool { UpdateInstaller.isHomebrewInstall }

    /// Starts or stops the daily search.
    func setAutomatic(_ enabled: Bool) {
        loop?.cancel()
        loop = nil
        guard enabled else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                if let self, Date().timeIntervalSince(self.lastSearch ?? .distantPast) >= Self.interval * 0.9 {
                    await self.find()
                }
                try? await Task.sleep(for: .seconds(6 * 60 * 60))
            }
        }
    }

    func find() async {
        if case .installing = status { return }
        status = .finding
        do {
            let release = try await ReleaseInfo.fetchLatest()
            lastSearch = Date()
            if let current = SemanticVersion(AppInfo.version), current < release.version {
                status = .available(release)
            } else {
                status = .upToDate
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func install() {
        guard let release = available else { return }
        if isHomebrewInstall {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(UpdateInstaller.brewCommand, forType: .string)
            return
        }
        status = .installing(release)
        Task {
            do {
                let app = try await UpdateInstaller.prepare(release)
                try UpdateInstaller.replaceAndRelaunch(with: app)
                NSApp.terminate(nil)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func openReleasePage() {
        NSWorkspace.shared.open(available?.pageURL ?? ReleaseInfo.releasesPage)
    }
}
