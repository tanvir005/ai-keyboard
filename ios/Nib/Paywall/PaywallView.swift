import SwiftUI
import NibKit

/// Screen 10 — Nib Pro.
///
/// Prices are static by design: "same price for everyone" is a stated product
/// commitment, so there are no server-driven price cohorts or offer
/// experiments here, and there should never be.
///
/// Purchases are stubbed for now — tapping the CTA flips the local Pro flag so
/// the rest of the app can be exercised. Real StoreKit 2 wiring (and
/// server-side receipt validation, which is what actually gates quota) lands
/// with the backend; see `ios/Nib/Paywall/Nib.storekit`.
struct PaywallView: View {
    @Environment(SharedSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Plan = .yearly

    enum Plan: String, CaseIterable, Identifiable {
        case yearly, monthly, lifetime
        var id: String { rawValue }

        var title: String {
            switch self {
            case .yearly: "Yearly"
            case .monthly: "Monthly"
            case .lifetime: "Lifetime"
            }
        }
        var price: String {
            switch self {
            case .yearly: "$29.99/yr"
            case .monthly: "$4.99/mo"
            case .lifetime: "$59.99"
            }
        }
        var note: String? {
            switch self {
            case .yearly: "SAVE 50%"
            case .monthly: nil
            case .lifetime: "one-time"
            }
        }
        /// Lifetime is a one-off purchase — no trial applies to it.
        var hasTrial: Bool { self != .lifetime }
    }

    private let benefits = [
        "Unlimited AI edits per day",
        "Custom tone presets",
        "Translate to 40+ languages",
        "Priority AI response speed",
    ]

    var body: some View {
        NibScreen {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NibStyle.Palette.inkFaint)
                    }
                }
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Nib Pro")
                        .font(NibStyle.Typography.display(30))
                        .foregroundStyle(NibStyle.Palette.ink)
                    Text("Unlimited edits. Every tone. Every language.")
                        .font(NibStyle.Typography.body(14))
                        .foregroundStyle(NibStyle.Palette.inkSoft)
                }
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(benefits, id: \.self) { CheckBullet(text: $0) }
                }
                .padding(.top, 24)

                VStack(spacing: 10) {
                    ForEach(Plan.allCases) { plan in
                        planRow(plan)
                    }
                }
                .padding(.top, 26)

                Spacer()

                NibPrimaryButton(title: selected.hasTrial ? "Start 7-day free trial" : "Buy Nib Pro") {
                    settings.isPro = true
                    dismiss()
                }

                Text("Cancel anytime · Billed via App Store · Same price for everyone")
                    .font(NibStyle.Typography.body(11))
                    .foregroundStyle(NibStyle.Palette.inkFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, NibStyle.Metrics.screenPadding)
        }
    }

    private func planRow(_ plan: Plan) -> some View {
        let isSelected = plan == selected
        return Button {
            selected = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(NibStyle.Typography.body(15, weight: .semibold))
                        .foregroundStyle(NibStyle.Palette.ink)
                    if let note = plan.note, plan != .yearly {
                        Text(note)
                            .font(NibStyle.Typography.body(12))
                            .foregroundStyle(NibStyle.Palette.inkFaint)
                    }
                }
                Spacer()
                if plan == .yearly, let note = plan.note {
                    Text(note)
                        .font(NibStyle.Typography.body(10, weight: .bold))
                        .foregroundStyle(NibStyle.Palette.onAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(NibStyle.Palette.red, in: Capsule())
                }
                Text(plan.price)
                    .font(NibStyle.Typography.body(15, weight: .semibold))
                    .foregroundStyle(NibStyle.Palette.ink)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: NibStyle.Metrics.cornerRadius)
                    .fill(NibStyle.Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: NibStyle.Metrics.cornerRadius)
                            .strokeBorder(isSelected ? NibStyle.Palette.red : .clear, lineWidth: 2)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}
