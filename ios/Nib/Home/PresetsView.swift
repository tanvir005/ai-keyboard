import SwiftUI
import NibKit

/// Presets — not in the original mockup. Full management behind Home's
/// horizontal preset row. Built-ins can't be deleted.
struct PresetsView: View {
    @Environment(SharedSettings.self) private var settings
    @State private var showCreator = false

    var body: some View {
        NibScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Tone presets")
                            .font(NibStyle.Typography.display(26))
                            .foregroundStyle(NibStyle.Palette.ink)
                        Spacer()
                        Button { showCreator = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(NibStyle.Palette.red)
                        }
                    }
                    .padding(.top, 18)

                    Text("Tones you can apply from the keyboard's Tone tool.")
                        .font(NibStyle.Typography.body(13))
                        .foregroundStyle(NibStyle.Palette.inkFaint)
                        .padding(.top, 6)

                    section(title: "Built in", presets: settings.tonePresets.filter(\.isBuiltIn))

                    let custom = settings.tonePresets.filter { !$0.isBuiltIn }
                    if custom.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Your presets")
                            Text("Create a preset to describe a tone in your own words.")
                                .font(NibStyle.Typography.body(13))
                                .foregroundStyle(NibStyle.Palette.inkFaint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(NibStyle.Palette.surface, in: RoundedRectangle(cornerRadius: NibStyle.Metrics.cornerRadius))
                        }
                        .padding(.top, 26)
                    } else {
                        section(title: "Your presets", presets: custom, deletable: true)
                    }
                }
                .padding(.horizontal, NibStyle.Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showCreator) { CustomToneCreatorView() }
    }

    private func section(title: String, presets: [TonePreset], deletable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            GroupedCard {
                ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                    GroupedRow(
                        title: preset.name,
                        subtitle: preset.instruction.isEmpty ? nil : preset.instruction,
                        showsDivider: index < presets.count - 1
                    ) {
                        if deletable {
                            Button {
                                settings.deletePreset(id: preset.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(NibStyle.Palette.inkFaint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.top, 26)
    }
}
