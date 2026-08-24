import SwiftUI
import NibKit

/// Screen 6 — Home.
struct HomeView: View {
    @Environment(SharedSettings.self) private var settings
    @State private var records: [EditRecord] = []
    @State private var selectedPreset: UUID = TonePreset.professional.id
    @State private var showPaywall = false
    @State private var showPresetCreator = false

    var body: some View {
        NibScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    streak
                    presets
                    recentEdits
                }
                .padding(.horizontal, NibStyle.Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .task { records = EditHistoryLog.readAll(limit: 4) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showPresetCreator) { CustomToneCreatorView() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(greeting)
                .font(NibStyle.Typography.display(26))
                .foregroundStyle(NibStyle.Palette.ink)
            Spacer()
            quotaChip
        }
        .padding(.top, 18)
    }

    private var quotaChip: some View {
        Button {
            // Parenthesised deliberately: `??` binds looser than `<=`, so
            // `a ?? 99 <= 3` would parse as `a ?? (99 <= 3)` and not compile.
            if (settings.quotaRemaining ?? .max) <= 3 { showPaywall = true }
        } label: {
            Text(quotaText)
                .font(NibStyle.Typography.body(12, weight: .semibold))
                .foregroundStyle(settings.isQuotaExhausted ? Color(hex: 0xFBF3E8) : NibStyle.Palette.inkSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(settings.isQuotaExhausted ? NibStyle.Palette.red : NibStyle.Palette.surface)
                }
        }
        .buttonStyle(.plain)
    }

    private var quotaText: String {
        guard let limit = settings.quotaLimit else { return "Pro · unlimited" }
        return "\(settings.quotaUsed) of \(limit) today"
    }

    private var streak: some View {
        Text("🔥 \(settings.streakDays)-day streak")
            .font(NibStyle.Typography.body(13))
            .foregroundStyle(NibStyle.Palette.inkSoft)
            .padding(.top, 6)
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Tone presets")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(settings.tonePresets) { preset in
                        NibChip(label: preset.name, isActive: preset.id == selectedPreset) {
                            selectedPreset = preset.id
                        }
                    }
                    NibChip(label: "+ New") { showPresetCreator = true }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 26)
    }

    private var recentEdits: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Recent edits")

            if records.isEmpty {
                Text("Edits you accept in the keyboard show up here.")
                    .font(NibStyle.Typography.body(13))
                    .foregroundStyle(NibStyle.Palette.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(NibStyle.Palette.surface, in: RoundedRectangle(cornerRadius: NibStyle.Metrics.cornerRadius))
            } else {
                GroupedCard {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        EditRow(record: record, showsDivider: index < records.count - 1)
                    }
                }
            }
        }
        .padding(.top, 26)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }
}

/// Before/after pair — struck-through original above the accepted rewrite.
struct EditRow: View {
    let record: EditRecord
    var showsDivider: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(record.sourceApp ?? "Keyboard") · \(record.tool)")
                    .font(NibStyle.Typography.sectionLabel)
                    .foregroundStyle(NibStyle.Palette.inkFaint)
                Text(record.before)
                    .font(NibStyle.Typography.body(13))
                    .strikethrough()
                    .foregroundStyle(NibStyle.Palette.inkFaint)
                Text(record.after)
                    .font(NibStyle.Typography.body(13))
                    .foregroundStyle(NibStyle.Palette.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if showsDivider {
                Rectangle().fill(NibStyle.Palette.divider).frame(height: 1).padding(.leading, 14)
            }
        }
    }
}
