import SwiftUI
import UIKit
import NibKit

/// Screen 5 — "One permission, fully explained".
///
/// Full Access is the #1 objection in competitor reviews (see
/// docs/screens/FEATURE_RESEARCH.md). The four bullets below are commitments,
/// not marketing: each one maps to a real constraint in the extension and the
/// backend. Don't soften this copy without changing the code that backs it.
struct FullAccessExplainerView: View {
    var onDone: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("One permission, fully explained")
                .font(NibStyle.Typography.display(23))
                .foregroundStyle(NibStyle.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 46)

            Text("iOS keyboards are sandboxed by default — Full Access is what lets Nib reach the AI at all. Here's exactly what that does and doesn't mean:")
                .font(NibStyle.Typography.body(14))
                .foregroundStyle(NibStyle.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 14) {
                CheckBullet(text: "**Only** sent when you tap a toolbar action — never continuously", tint: NibStyle.Palette.green)
                CheckBullet(text: "Only the selected text (or current draft) — not your keystroke history", tint: NibStyle.Palette.green)
                CheckBullet(text: "Never logged after the AI responds — nothing stored on our servers", tint: NibStyle.Palette.green)
                CheckBullet(text: "Revoke anytime — Nib still works as a plain keyboard without it", tint: NibStyle.Palette.green)
            }
            .padding(.top, 22)

            GroupedCard {
                GroupedRow(title: "Allow Full Access", showsDivider: false) {
                    StaticToggle(isOn: true)
                }
            }
            .padding(.top, 24)

            Text("This toggle lives in iOS Settings — Nib can't switch it on for you.")
                .font(NibStyle.Typography.body(12))
                .foregroundStyle(NibStyle.Palette.inkFaint)
                .padding(.top, 8)

            Spacer()

            NibPrimaryButton(title: "Got it", action: onDone)

            Button("Full privacy policy →") {
                if let url = URL(string: "https://nib.app/privacy") { openURL(url) }
            }
            .font(NibStyle.Typography.body(13))
            .foregroundStyle(NibStyle.Palette.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, NibStyle.Metrics.screenPadding)
    }
}
