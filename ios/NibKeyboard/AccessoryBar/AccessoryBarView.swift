import SwiftUI
import NibKit

/// The strip above the keys — Nib's entire product surface.
struct AccessoryBarView: View {
    @Bindable var model: ToolbarViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !model.hasFullAccess {
                FullAccessBanner()
            } else {
                resultArea
                if model.selectedTool == .ask { AskAIBar(model: model) }
                if model.selectedTool == .tone { toneSubChips }
                if model.selectedTool == .translate { languageSubChips }
                ToolChipRow(model: model)
            }
        }
        .background(NibStyle.Palette.surface)
    }

    // MARK: - Result

    @ViewBuilder
    private var resultArea: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Nib is thinking…")
                    .font(NibStyle.Typography.body(13))
                    .foregroundStyle(NibStyle.Palette.inkFaint)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        case .error(let error):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(NibStyle.Palette.red)
                Text(error.userMessage)
                    .font(NibStyle.Typography.body(13))
                    .foregroundStyle(NibStyle.Palette.inkSoft)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        case .suggestions(let suggestions):
            SuggestionCard(
                suggestions: suggestions,
                label: model.selectedTool == .tone ? model.tonePreset.name : (model.selectedTool?.title ?? ""),
                onAccept: { model.accept($0) },
                onRegenerate: { model.regenerate() }
            )
        }
    }

    // MARK: - Sub-option rows

    private var toneSubChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(model.tonePresets) { preset in
                    NibChip(label: preset.name, isActive: preset.id == model.tonePreset.id) {
                        model.selectTone(preset)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
    }

    private var languageSubChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(["Spanish", "French", "German", "Japanese", "Arabic", "Hebrew"], id: \.self) { lang in
                    NibChip(label: lang, isActive: lang == model.targetLanguage) {
                        model.selectLanguage(lang)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
    }
}

/// Shown when Full Access is off. The keys below keep working — Nib degrades to
/// a plain keyboard rather than breaking, which is what the onboarding promises.
struct FullAccessBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NibStyle.Palette.red)
            VStack(alignment: .leading, spacing: 1) {
                Text("Turn on Full Access to use Nib's tools")
                    .font(NibStyle.Typography.body(12.5, weight: .semibold))
                    .foregroundStyle(NibStyle.Palette.ink)
                Text("Settings → General → Keyboard → Keyboards → Nib")
                    .font(NibStyle.Typography.body(11))
                    .foregroundStyle(NibStyle.Palette.inkFaint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

/// Horizontally scrollable tool row.
struct ToolChipRow: View {
    @Bindable var model: ToolbarViewModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(NibTool.allCases) { tool in
                    NibChip(
                        label: tool.title,
                        systemImage: tool.symbol,
                        isActive: model.selectedTool == tool
                    ) {
                        model.select(tool)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}

/// Free-text prompt bar for the Ask AI tool.
struct AskAIBar: View {
    @Bindable var model: ToolbarViewModel

    private let suggestions = ["Summarize this", "Turn into an email", "List the action items"]

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(NibStyle.Palette.red)
                TextField("Ask anything…", text: $model.askPrompt)
                    .font(NibStyle.Typography.body(14))
                    .textFieldStyle(.plain)
                    .submitLabel(.go)
                    .onSubmit { model.submitAsk() }
                Button { model.submitAsk() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(NibStyle.Palette.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 11)
                    .fill(NibStyle.Palette.paper)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(NibStyle.Palette.red, lineWidth: 1.5))
            }

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(suggestions, id: \.self) { s in
                        NibChip(label: s) {
                            model.askPrompt = s
                            model.submitAsk()
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }
}
