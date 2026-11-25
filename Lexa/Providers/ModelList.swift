import Foundation

/// A model entry returned by a provider, with its release date when known.
nonisolated struct ModelInfo: Identifiable, Hashable, Sendable {
    let id: String
    var releaseDate: ModelReleaseDate?
}

/// A model release date with day or month precision, formatted in UTC.
nonisolated struct ModelReleaseDate: Hashable, Comparable, Sendable {
    enum Precision: Hashable, Sendable {
        case day
        case month
    }

    let date: Date
    let precision: Precision

    init(timestamp: TimeInterval, precision: Precision = .day) {
        self.date = Date(timeIntervalSince1970: timestamp)
        self.precision = precision
    }

    var timestamp: TimeInterval { date.timeIntervalSince1970 }

    var displayText: String {
        switch precision {
        case .day: Self.dayFormat.format(date)
        case .month: Self.monthFormat.format(date)
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timestamp < rhs.timestamp
    }

    private static let dayFormat = Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt)
    private static let monthFormat = Date.FormatStyle(timeZone: .gmt).month(.abbreviated).year()
}

/// Parses OpenAI-compatible `/models` payloads and orders models newest-first.
///
/// Ordering rules:
/// 1. Dated models come first, descending by release date.
/// 2. Undated models follow, descending by numeric version within the same model family.
/// 3. Ties break alphabetically by model ID.
/// 4. OpenRouter pins `openrouter/free` at the top and keeps only `:free` models.
nonisolated enum ModelList {
    static func parse(
        _ data: Data,
        providerID: String,
        knownDates: [String: ModelReleaseDate] = [:]
    ) -> [ModelInfo] {
        let entries = extractEntries(from: data)
        let normalizedKnown = knownDates.isEmpty
            ? [String: ModelReleaseDate]()
            : Dictionary(knownDates.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: max)

        var items: [(info: ModelInfo, key: SortKey)] = entries.compactMap { entry in
            guard let id = extractID(from: entry) else { return nil }
            let date = releaseDate(of: entry)
                ?? knownDate(for: id, in: normalizedKnown)
                ?? releaseDate(fromModelID: id)
            let info = ModelInfo(id: id, releaseDate: date)
            return (info, SortKey(info))
        }

        if providerID == Provider.openRouter.id {
            items = items.filter { $0.info.id.hasSuffix(":free") }
        }

        items.sort { $0.key < $1.key }

        var seen = Set<String>()
        var models = items.map(\.info).filter { seen.insert($0.id).inserted }
        if providerID == Provider.openRouter.id {
            models.insert(ModelInfo(id: "openrouter/free"), at: 0)
        }
        return models
    }

    // MARK: - Release date extraction

    static func releaseDate(of entry: [String: Any]) -> ModelReleaseDate? {
        for key in ["release_date", "released_at", "created", "created_at", "modified_at"] {
            if let date = parseTimestamp(entry[key]) { return date }
        }
        return nil
    }

    /// Extracts an explicit release date embedded in a model ID
    /// (for example `2025-06-17`, `20261118`, `09-2025`, or `2025-09`).
    static func releaseDate(fromModelID id: String) -> ModelReleaseDate? {
        if let match = id.firstMatch(of: /(?:^|[^\d])(20\d{2})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])(?:$|[^\d])/),
           let date = try? Date("\(match.1)-\(match.2)-\(match.3)", strategy: isoDayStyle) {
            return ModelReleaseDate(timestamp: date.timeIntervalSince1970, precision: .day)
        }
        if let match = id.firstMatch(of: /(?:^|[^\d])(20\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])(?:$|[^\d])/),
           let date = try? Date("\(match.1)-\(match.2)-\(match.3)", strategy: isoDayStyle) {
            return ModelReleaseDate(timestamp: date.timeIntervalSince1970, precision: .day)
        }
        if let match = id.firstMatch(of: /(?:^|[^\d])(0[1-9]|1[0-2])-(20\d{2})(?:$|[^\d])/),
           let date = try? Date("\(match.2)-\(match.1)-01", strategy: isoDayStyle) {
            return ModelReleaseDate(timestamp: date.timeIntervalSince1970, precision: .month)
        }
        if let match = id.firstMatch(of: /(?:^|[^\d])(20\d{2})-(0[1-9]|1[0-2])(?:$|[^\d])/),
           let date = try? Date("\(match.1)-\(match.2)-01", strategy: isoDayStyle) {
            return ModelReleaseDate(timestamp: date.timeIntervalSince1970, precision: .month)
        }
        return nil
    }

    // MARK: - Helpers

    private static let isoDayStyle = Date.ISO8601FormatStyle().year().month().day()
    private static let isoTimestampStyles: [Date.ISO8601FormatStyle] = [
        .init(includingFractionalSeconds: true),
        .init(),
        isoDayStyle,
    ]

    private static func extractEntries(from data: Data) -> [[String: Any]] {
        let json = try? JSONSerialization.jsonObject(with: data)
        if let object = json as? [String: Any] {
            return (object["data"] as? [[String: Any]]) ?? (object["models"] as? [[String: Any]]) ?? []
        }
        return (json as? [[String: Any]]) ?? []
    }

    private static func extractID(from entry: [String: Any]) -> String? {
        guard var id = (entry["id"] as? String) ?? (entry["name"] as? String) else { return nil }
        if id.hasPrefix("models/") { id.removeFirst(7) }
        return id.isEmpty ? nil : id
    }

    private static func knownDate(for id: String, in known: [String: ModelReleaseDate]) -> ModelReleaseDate? {
        guard !known.isEmpty else { return nil }
        let lower = id.lowercased()
        if let date = known[lower] { return date }
        // Match revision-pinned IDs such as "gemini-2.5-flash-001" against "gemini-2.5-flash".
        if let match = lower.firstMatch(of: /^(.+)-\d{3}$/) {
            return known[String(match.1)]
        }
        return nil
    }

    private static func parseTimestamp(_ value: Any?) -> ModelReleaseDate? {
        guard let value else { return nil }
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            return normalizeEpoch(number.doubleValue).map { ModelReleaseDate(timestamp: $0) }
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if let numeric = Double(trimmed) {
                return normalizeEpoch(numeric).map { ModelReleaseDate(timestamp: $0) }
            }
            for style in isoTimestampStyles {
                if let date = try? Date(trimmed, strategy: style) {
                    return normalizeEpoch(date.timeIntervalSince1970).map { ModelReleaseDate(timestamp: $0) }
                }
            }
        }
        return nil
    }

    private static func normalizeEpoch(_ value: Double) -> TimeInterval? {
        guard value.isFinite, value > 0 else { return nil }
        return value >= 1_000_000_000_000 ? value / 1000 : value
    }

    // MARK: - Strict total ordering

    private struct SortKey: Comparable {
        let releaseDate: ModelReleaseDate?
        let group: String
        let hasVersion: Bool
        let version: [Int]
        let id: String

        init(_ model: ModelInfo) {
            self.releaseDate = model.releaseDate
            self.id = model.id
            let lower = model.id.lowercased()
            if let match = lower.firstMatch(of: /^([a-z][a-z-]*?)-(\d+(?:\.\d+)*)(?=$|[^0-9.])/) {
                var parsed = match.2.split(separator: ".").compactMap { Int($0) }
                while parsed.count > 1, parsed.last == 0 { parsed.removeLast() }
                if !parsed.isEmpty {
                    self.group = String(match.1)
                    self.hasVersion = true
                    self.version = parsed
                    return
                }
            }
            self.group = lower
            self.hasVersion = false
            self.version = []
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            switch (lhs.releaseDate, rhs.releaseDate) {
            case let (a?, b?) where a != b: return a > b
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil):
                if lhs.group != rhs.group { return lhs.group < rhs.group }
                if lhs.hasVersion != rhs.hasVersion { return lhs.hasVersion }
                if lhs.version != rhs.version {
                    for (a, b) in zip(lhs.version, rhs.version) where a != b { return a > b }
                    return lhs.version.count > rhs.version.count
                }
                return lhs.id < rhs.id
            default:
                return lhs.id < rhs.id
            }
        }
    }
}
