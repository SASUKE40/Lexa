import SwiftUI

nonisolated enum ModelSearch {
    /// Keeps the models whose name contains every word of the query (case-insensitive).
    /// Models whose short name (after the last "/") starts with the first word come first.
    static func filter(_ models: [ModelInfo], query: String) -> [ModelInfo] {
        filter(models, query: query, id: \.id)
    }

    static func filter(_ models: [String], query: String) -> [String] {
        filter(models, query: query, id: \.self)
    }

    private static func filter<T>(_ items: [T], query: String, id: (T) -> String) -> [T] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first else { return items }
        let matches = items.enumerated().filter { _, item in
            let name = id(item).lowercased()
            return words.allSatisfy { name.contains($0) }
        }
        return matches.sorted { a, b in
            let aRank = shortName(id(a.element)).hasPrefix(first) ? 0 : 1
            let bRank = shortName(id(b.element)).hasPrefix(first) ? 0 : 1
            return aRank == bRank ? a.offset < b.offset : aRank < bRank
        }.map(\.element)
    }

    private static func shortName(_ model: String) -> String {
        String(model.lowercased().split(separator: "/").last ?? "")
    }
}

/// A button that opens a searchable popover with models ordered newest-first.
struct ModelPicker: View {
    let providerID: String
    let models: [ModelInfo]
    let selection: String
    let canDownload: Bool
    /// Downloads the list when the popover opens (the list has only the suggested models).
    let downloadOnOpen: Bool
    let isDownloading: Bool
    let error: String?
    let onDownload: () -> Void
    let onSelect: (String) -> Void

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            if isDownloading, !isOpen {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .frame(width: 14, height: 14)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("Select a model")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            ModelSearchList(providerID: providerID, models: models, selection: selection,
                            canDownload: canDownload, downloadOnOpen: downloadOnOpen,
                            isDownloading: isDownloading, error: error, onDownload: onDownload) { model in
                onSelect(model)
                isOpen = false
            }
        }
    }
}

private struct ModelSearchList: View {
    let providerID: String
    let models: [ModelInfo]
    let selection: String
    let canDownload: Bool
    let downloadOnOpen: Bool
    let isDownloading: Bool
    let error: String?
    let onDownload: () -> Void
    let onSelect: (String) -> Void

    @State private var query = ""
    @State private var highlightedIndex: Int?
    @FocusState private var searchFocused: Bool

    private var matches: [ModelInfo] { ModelSearch.filter(models, query: query) }
    private var hasReleaseDates: Bool { models.contains { $0.releaseDate != nil } }

    /// Indices where the list transitions between dated and undated models (only when unfiltered).
    private var sectionBreaks: Set<Int> {
        guard query.isEmpty, hasReleaseDates else { return [] }
        var breaks = Set<Int>()
        for index in 1..<matches.count {
            let previousDated = matches[index - 1].releaseDate != nil
            let currentDated = matches[index].releaseDate != nil
            if previousDated != currentDated { breaks.insert(index) }
        }
        return breaks
    }

    private var activeIndex: Int? {
        if let highlightedIndex, matches.indices.contains(highlightedIndex) {
            return highlightedIndex
        }
        return query.isEmpty ? nil : (matches.isEmpty ? nil : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 430)
        .onAppear {
            searchFocused = true
            if canDownload, downloadOnOpen, !isDownloading { onDownload() }
        }
        .onChange(of: query) { highlightedIndex = nil }
        .onKeyPress(.downArrow) {
            moveHighlight(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveHighlight(by: -1)
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Find a model by name", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    if let index = activeIndex, matches.indices.contains(index) {
                        onSelect(matches[index].id)
                    } else if let first = matches.first {
                        onSelect(first.id)
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear the search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(10)
    }

    @ViewBuilder
    private var list: some View {
        if matches.isEmpty {
            Text(models.isEmpty ? "There are no models in the list." : "No model name contains \"\(query)\".")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 72)
        } else {
            let breaks = sectionBreaks
            let contentHeight = CGFloat(matches.count) * 28 + CGFloat(breaks.count) * 9 + 8
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { index, model in
                            if breaks.contains(index) {
                                Divider()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                            }
                            ModelRow(
                                providerID: providerID,
                                model: model,
                                isSelected: model.id == selection,
                                isHighlighted: activeIndex == index
                            ) { onSelect(model.id) }
                                .id(model.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: min(contentHeight, 320))
                .onChange(of: highlightedIndex) { _, newValue in
                    if let index = newValue, matches.indices.contains(index) {
                        withAnimation(.snappy(duration: 0.12)) {
                            proxy.scrollTo(matches[index].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var footerSummary: String {
        if !query.isEmpty {
            return "\(matches.count) of \(models.count) models"
        }
        return hasReleaseDates ? "\(models.count) models · Newest first" : "\(models.count) models"
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(footerSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isDownloading { ProgressView().controlSize(.small) }
                if canDownload {
                    Button {
                        onDownload()
                    } label: {
                        Label("Download the Model List", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .disabled(isDownloading)
                }
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
    }

    private func moveHighlight(by delta: Int) {
        guard !matches.isEmpty else { return }
        if let current = activeIndex {
            highlightedIndex = min(max(current + delta, 0), matches.count - 1)
        } else {
            highlightedIndex = delta > 0 ? 0 : matches.count - 1
        }
    }
}

private struct ModelRow: View {
    let providerID: String
    let model: ModelInfo
    let isSelected: Bool
    /// Highlighted via arrow keys or first search match, which Return selects.
    let isHighlighted: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 12)
                ModelLogo(modelID: model.id, providerID: providerID, size: 17)
                Text(model.id)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 12)
                if let releaseDate = model.releaseDate {
                    Text(releaseDate.displayText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered || isHighlighted ? Color.accentColor.opacity(isHovered ? 0.18 : 0.12) : .clear)
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
