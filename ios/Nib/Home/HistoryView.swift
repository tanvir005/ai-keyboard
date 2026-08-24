import SwiftUI
import NibKit

/// History — not in the original mockup. Structure follows Home's "Recent
/// edits" visual language; this is the complete list behind that preview.
struct HistoryView: View {
    @State private var records: [EditRecord] = []
    @State private var filter: NibTool?

    private var filtered: [EditRecord] {
        guard let filter else { return records }
        return records.filter { $0.tool == filter.title }
    }

    private var grouped: [(day: Date, records: [EditRecord])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
            .map { (day: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NibScreen {
            VStack(alignment: .leading, spacing: 0) {
                Text("History")
                    .font(NibStyle.Typography.display(26))
                    .foregroundStyle(NibStyle.Palette.ink)
                    .padding(.horizontal, NibStyle.Metrics.screenPadding)
                    .padding(.top, 18)

                filterRow

                if grouped.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .task { records = EditHistoryLog.readAll() }
    }

    private var filterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                NibChip(label: "All", isActive: filter == nil) { filter = nil }
                ForEach(NibTool.allCases) { tool in
                    NibChip(label: tool.title, isActive: filter == tool) {
                        filter = filter == tool ? nil : tool
                    }
                }
            }
            .padding(.horizontal, NibStyle.Metrics.screenPadding)
        }
        .scrollIndicators(.hidden)
        .padding(.top, 16)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(grouped, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: group.day.formatted(.dateTime.weekday(.wide).month().day()))
                        GroupedCard {
                            ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                                EditRow(record: record, showsDivider: index < group.records.count - 1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, NibStyle.Metrics.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 26))
                .foregroundStyle(NibStyle.Palette.kraftCardLine)
            Text(filter == nil ? "No edits yet" : "No \(filter!.title) edits yet")
                .font(NibStyle.Typography.body(15, weight: .semibold))
                .foregroundStyle(NibStyle.Palette.inkSoft)
            Text("Everything you accept in the keyboard is kept here, on this device only.")
                .font(NibStyle.Typography.body(13))
                .foregroundStyle(NibStyle.Palette.inkFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
