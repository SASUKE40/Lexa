import SwiftUI

nonisolated enum ModelSearch {
    /// Keeps the models whose name contains every word of the query (case-insensitive).
    /// Models whose short name (after the last "/") starts with the first word come first.
    static func filter(_ models: [String], query: String) -> [String] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first else { return models }
        let matches = models.enumerated().filter { _, model in
            let name = model.lowercased()
            return words.allSatisfy { name.contains($0) }
        }
        return matches.sorted { a, b in
            let aRank = shortName(a.element).hasPrefix(first) ? 0 : 1
            let bRank = shortName(b.element).hasPrefix(first) ? 0 : 1
            return aRank == bRank ? a.offset < b.offset : aRank < bRank
        }.map(\.element)
    }

    private static func shortName(_ model: String) -> String {
        String(model.lowercased().split(separator: "/").last ?? "")
    }
}

/// A chevron button that opens a popover with a model list that you can search by name.
struct ModelPicker: View {
    let models: [String]
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
            Image(systemName: "chevron.up.chevron.down")
        }
        .buttonStyle(.borderless)
        .help("Select a model")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            ModelSearchList(models: models, selection: selection, canDownload: canDownload,
                            downloadOnOpen: downloadOnOpen, isDownloading: isDownloading,
                            error: error, onDownload: onDownload) { model in
                onSelect(model)
                isOpen = false
            }
        }
    }
}

private struct ModelSearchList: View {
    let models: [String]
    let selection: String
    let canDownload: Bool
    let downloadOnOpen: Bool
    let isDownloading: Bool
    let error: String?
    let onDownload: () -> Void
    let onSelect: (String) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var matches: [String] { ModelSearch.filter(models, query: query) }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 380)
        .onAppear {
            searchFocused = true
            if canDownload, downloadOnOpen, !isDownloading { onDownload() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find a model by name", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { if let first = matches.first { onSelect(first) } }
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
        .padding(10)
    }

    @ViewBuilder
    private var list: some View {
        if matches.isEmpty {
            Text(models.isEmpty ? "There are no models in the list." : "No model name contains \"\(query)\".")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 64)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.element) { index, model in
                        ModelRow(model: model, isSelected: model == selection,
                                 isDefault: index == 0 && !query.isEmpty) { onSelect(model) }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: min(CGFloat(matches.count) * 26 + 8, 320))
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(query.isEmpty ? "\(models.count) models" : "\(matches.count) of \(models.count) models")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isDownloading { ProgressView().controlSize(.small) }
                if canDownload {
                    Button("Download the Model List", action: onDownload)
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
}

private struct ModelRow: View {
    let model: String
    let isSelected: Bool
    /// The first match, which Return selects.
    let isDefault: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(model)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                if isSelected { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered || isDefault ? Color.accentColor.opacity(isHovered ? 0.18 : 0.1) : .clear)
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
