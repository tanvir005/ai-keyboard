import SwiftUI
import NibKit

/// Screen 4 — "Switch to Nib anytime".
///
/// Purely educational. The globe-key picker is drawn and owned by iOS; nothing
/// here is ours to build. It earns a screen because this is the *recurring*
/// interaction, not a one-time setup step.
struct SwitchToNibEducationView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onContinue) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NibStyle.Palette.inkFaint)
                }
            }
            .padding(.horizontal, NibStyle.Metrics.screenPadding)
            .padding(.top, 10)

            Spacer()

            RoundedRectangle(cornerRadius: 14)
                .fill(NibStyle.Palette.illustration)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "globe")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(NibStyle.Palette.red)
                }

            Text("Switch to Nib anytime")
                .font(NibStyle.Typography.display(23))
                .foregroundStyle(NibStyle.Palette.ink)
                .padding(.top, 22)

            VStack(alignment: .leading, spacing: 13) {
                CheckBullet(text: "Long-press the globe key")
                CheckBullet(text: "Choose **\"Nib\"** from the list")
            }
            .padding(.top, 22)
            .padding(.horizontal, 44)

            KeyboardPickerIllustration()
                .padding(.top, 30)
                .padding(.horizontal, NibStyle.Metrics.screenPadding)

            Text("always one long-press away")
                .font(NibStyle.Typography.display(12, weight: .regular))
                .foregroundStyle(NibStyle.Palette.red)
                .padding(.top, 12)

            Spacer()

            NibPrimaryButton(title: "Got it", action: onContinue)
                .padding(.horizontal, NibStyle.Metrics.screenPadding)
                .padding(.bottom, 12)
        }
    }
}

/// Mimics the system keyboard-picker popover.
private struct KeyboardPickerIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            row(title: "Nib · English", isActive: true)
            Rectangle().fill(NibStyle.Palette.divider).frame(height: 1)
            row(title: "English (UK)", isActive: false)
        }
        .background(NibStyle.Palette.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(NibStyle.Palette.kraftCardLine, lineWidth: 1))
    }

    private func row(title: String, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 12))
                .foregroundStyle(isActive ? NibStyle.Palette.red : NibStyle.Palette.inkFaint)
            Text(title)
                .font(NibStyle.Typography.body(13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? NibStyle.Palette.ink : NibStyle.Palette.inkSoft)
            Spacer()
            if isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NibStyle.Palette.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
