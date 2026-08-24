import SwiftUI
import NibKit

/// Custom tone creation — reached from Home's "+ New" chip and the Presets
/// screen. Not in the original mockup.
///
/// The preview button runs the tone through the same client the keyboard uses,
/// so the user sees the effect before committing the preset.
struct CustomToneCreatorView: View {
    @Environment(SharedSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var instruction = ""
    @State private var preview: String?
    @State private var isPreviewing = false

    private let sample = "cant make it tonight, something came up"
    private let client = StubAPIClient()

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !instruction.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            NibScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        field(label: "Name", placeholder: "Diplomatic", text: $name, axis: .horizontal)
                        field(
                            label: "How should Nib write?",
                            placeholder: "Soften disagreement, stay warm but direct, never passive-aggressive.",
                            text: $instruction,
                            axis: .vertical
                        )
                        previewSection
                    }
                    .padding(.horizontal, NibStyle.Metrics.screenPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.addPreset(TonePreset(name: name.trimmingCharacters(in: .whitespaces),
                                                      instruction: instruction))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func field(label: String, placeholder: String, text: Binding<String>, axis: Axis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label)
            TextField(placeholder, text: text, axis: axis)
                .font(NibStyle.Typography.body(15))
                .lineLimit(axis == .vertical ? 3...6 : 1...1)
                .padding(12)
                .background(NibStyle.Palette.surface, in: RoundedRectangle(cornerRadius: NibStyle.Metrics.cornerRadius))
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Preview")
            Text("\"\(sample)\"")
                .font(NibStyle.Typography.body(13))
                .foregroundStyle(NibStyle.Palette.inkFaint)

            if let preview {
                Text(preview)
                    .font(NibStyle.Typography.body(14))
                    .foregroundStyle(NibStyle.Palette.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(NibStyle.Palette.surface, in: RoundedRectangle(cornerRadius: NibStyle.Metrics.cornerRadius))
            }

            Button {
                Task { await runPreview() }
            } label: {
                HStack(spacing: 6) {
                    if isPreviewing { ProgressView().controlSize(.small) }
                    Text(isPreviewing ? "Thinking…" : "Preview this tone")
                }
                .font(NibStyle.Typography.body(14, weight: .semibold))
                .foregroundStyle(NibStyle.Palette.red)
            }
            .buttonStyle(.plain)
            .disabled(instruction.trimmingCharacters(in: .whitespaces).isEmpty || isPreviewing)
        }
    }

    private func runPreview() async {
        isPreviewing = true
        defer { isPreviewing = false }
        let scope = TextContextResolver.resolve(before: sample)
        let result = try? await client.suggest(
            tool: .tone,
            scope: scope,
            options: ToolOptions(tonePreset: name.isEmpty ? "Custom" : name),
            prompt: instruction
        )
        preview = result?.first
    }
}
