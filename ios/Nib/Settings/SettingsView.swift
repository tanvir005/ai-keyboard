import SwiftUI
import UIKit
import NibKit

/// Screen 9 — Settings.
struct SettingsView: View {
    @Environment(SharedSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false
    @State private var showClearConfirm = false
    @State private var showForgetConfirm = false

    /// `SharedSettings` writes straight through to the App Group, so a plain
    /// get/set binding is both correct and simpler than threading `@Bindable`
    /// through computed properties.
    private func toggle(_ keyPath: ReferenceWritableKeyPath<SharedSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }

    var body: some View {
        NibScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings")
                        .font(NibStyle.Typography.display(26))
                        .foregroundStyle(NibStyle.Palette.ink)
                        .padding(.top, 18)

                    keyboardSection
                    generalSection
                    fullAccessStatus
                }
                .padding(.horizontal, NibStyle.Metrics.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .confirmationDialog("Clear edit history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) { EditHistoryLog.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every saved edit from this device. It can't be undone.")
        }
        .confirmationDialog(
            "Clear learned words?",
            isPresented: $showForgetConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear learned words", role: .destructive) { settings.forgetLearnedWords() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Nib forgets the phrases it has picked up from your typing. Predictions start again from the basics.")
        }
    }

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Keyboard")
            GroupedCard {
                GroupedRow(title: "Language") {
                    HStack(spacing: 4) {
                        Text("English (US)")
                            .font(NibStyle.Typography.body(14))
                            .foregroundStyle(NibStyle.Palette.inkFaint)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NibStyle.Palette.inkFaint)
                    }
                }
                GroupedRow(title: "Sound") { Toggle("", isOn: toggle(\.soundEnabled)).labelsHidden() }
                GroupedRow(title: "Haptics") { Toggle("", isOn: toggle(\.hapticsEnabled)).labelsHidden() }
                GroupedRow(
                    title: "Prediction",
                    subtitle: "Suggests the next word from phrases you type often. Learned on this device and never sent anywhere — never from password fields, and never anything containing a number."
                ) {
                    Toggle("", isOn: toggle(\.predictionEnabled)).labelsHidden()
                }
                GroupedRow(
                    title: "Read full draft, not just selection",
                    subtitle: "Off by default. Needed for whole-message actions like Fix, but keeps Mail and other sensitive apps text-select-only until you turn it on.",
                    showsDivider: false
                ) {
                    Toggle("", isOn: toggle(\.readFullDraft)).labelsHidden()
                }
            }
        }
        .padding(.top, 26)
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "General")
            GroupedCard {
                Button { showPaywall = true } label: {
                    GroupedRow(title: "Manage subscription") {
                        HStack(spacing: 4) {
                            Text(settings.isPro ? "Nib Pro" : "Free")
                                .font(NibStyle.Typography.body(14))
                                .foregroundStyle(NibStyle.Palette.inkFaint)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(NibStyle.Palette.inkFaint)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button { showClearConfirm = true } label: {
                    GroupedRow(title: "Clear edit history") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NibStyle.Palette.inkFaint)
                    }
                }
                .buttonStyle(.plain)

                Button { showForgetConfirm = true } label: {
                    GroupedRow(title: "Clear learned words") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NibStyle.Palette.inkFaint)
                    }
                }
                .buttonStyle(.plain)

                link(title: "Privacy Policy", url: "https://nib.app/privacy")
                link(title: "Contact support", url: "mailto:support@nib.app", showsDivider: false)
            }
        }
        .padding(.top, 26)
    }

    private func link(title: String, url: String, showsDivider: Bool = true) -> some View {
        Button {
            if let url = URL(string: url) { openURL(url) }
        } label: {
            GroupedRow(title: title, showsDivider: showsDivider) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NibStyle.Palette.inkFaint)
            }
        }
        .buttonStyle(.plain)
    }

    /// The host app can't read `hasFullAccess` itself — only the extension can.
    /// So this reports what the keyboard last saw, and says so.
    private var fullAccessStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(settings.lastKnownHasFullAccess ? NibStyle.Palette.green : NibStyle.Palette.toggleOff)
                    .frame(width: 7, height: 7)
                Text(settings.lastKnownHasFullAccess ? "Full Access on" : "Full Access off")
                    .font(NibStyle.Typography.body(13, weight: .semibold))
                    .foregroundStyle(NibStyle.Palette.inkSoft)
            }
            Text(statusCaption)
                .font(NibStyle.Typography.body(12))
                .foregroundStyle(NibStyle.Palette.inkFaint)
        }
        .padding(.top, 26)
    }

    private var statusCaption: String {
        guard let checked = settings.fullAccessCheckedAt else {
            return "Nib hasn't been used as a keyboard yet."
        }
        return "As of the last time you used the Nib keyboard, \(checked.formatted(.relative(presentation: .named)))."
    }
}
