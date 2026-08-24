import SwiftUI
import UIKit
import NibKit

/// Screen 3 — "Turn on Nib".
///
/// iOS has no API to add a keyboard programmatically, so this can only explain
/// the manual path and deep-link to Settings. There is also no public way for
/// the host app to ask "is Nib enabled?" — the extension writes that flag into
/// the App Group the first time it runs.
struct TurnOnNibView: View {
    var onContinue: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Turn on Nib")
                .font(NibStyle.Typography.display(26))
                .foregroundStyle(NibStyle.Palette.ink)
                .padding(.top, 48)

            VStack(alignment: .leading, spacing: 14) {
                CheckBullet(text: "Open **Settings → General → Keyboard**")
                CheckBullet(text: "Tap **Keyboards → Add New Keyboard**")
                CheckBullet(text: "Choose **Nib** from Third-Party Keyboards")
            }
            .padding(.top, 24)

            GroupedCard {
                GroupedRow(title: "Keyboards", subtitle: "2") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NibStyle.Palette.inkFaint)
                }
                GroupedRow(title: "Nib") {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NibStyle.Palette.green)
                }
                GroupedRow(title: "Allow Full Access", showsDivider: false) {
                    StaticToggle(isOn: false)
                }
                .opacity(0.45) // dimmed — this comes next, on the following screen
            }
            .padding(.top, 26)

            Spacer()

            NibPrimaryButton(title: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .padding(.bottom, 10)

            Button("I've done this — continue", action: onContinue)
                .font(NibStyle.Typography.body(14))
                .foregroundStyle(NibStyle.Palette.inkFaint)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, NibStyle.Metrics.screenPadding)
    }
}

/// Non-interactive toggle used to depict iOS Settings rows we don't control.
struct StaticToggle: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? NibStyle.Palette.green : NibStyle.Palette.toggleOff)
            .frame(width: 36, height: 21)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: 17, height: 17)
                    .padding(.horizontal, 2)
            }
    }
}
