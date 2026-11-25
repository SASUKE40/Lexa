import SwiftUI

struct UsageSettingsView: View {
    let usage: UsageTracker

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    UsageSummaryCard(title: "Today", totals: usage.today)
                    UsageSummaryCard(title: "All Time", totals: usage.allTime)
                }
                .padding(.vertical, 2)
            } header: {
                Text("Summary")
            }

            Section {
                let rows = usage.rankedProviders
                if rows.isEmpty {
                    Text("No usage data yet. Use Lexa on selected text to record tokens and cost.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(rows, id: \.provider.id) { item in
                        LabeledContent {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(UsageFormatting.cost(item.totals.costUSD))
                                    .font(.body.monospacedDigit().weight(.medium))
                                Text("\(UsageFormatting.tokens(item.totals.inputTokens)) in · \(UsageFormatting.tokens(item.totals.outputTokens)) out")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                ModelLogo(provider: item.provider, size: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.provider.name)
                                    Text(UsageFormatting.requests(item.totals.requests))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("By Provider")
            } footer: {
                Text("Lexa keeps usage data on this Mac. If a provider does not send a cost, Lexa estimates the cost from public prices.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                HStack {
                    Text("Clear all recorded tokens and costs.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset Usage") { usage.reset() }
                        .disabled(usage.allTime.requests == 0)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { usage.refreshDay() }
    }
}

private struct UsageSummaryCard: View {
    let title: String
    let totals: UsageTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(UsageFormatting.cost(totals.costUSD))
                .font(.title2.monospacedDigit().weight(.semibold))
            Text("\(UsageFormatting.tokens(totals.totalTokens)) tokens · \(UsageFormatting.requests(totals.requests))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 0.5)
        )
    }
}
