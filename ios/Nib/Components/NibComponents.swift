import SwiftUI
import NibKit

// Shared building blocks matching the mockup's visual language.

/// Full-width red pill — the primary CTA on every onboarding screen.
struct NibPrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NibStyle.Typography.body(16, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFBF3E8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(NibStyle.Palette.red, in: RoundedRectangle(cornerRadius: NibStyle.Metrics.buttonRadius))
        }
        .buttonStyle(.plain)
    }
}

/// Small uppercase monospace label ("TONE PRESETS", "RECENT EDITS").
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(NibStyle.Typography.sectionLabel)
            .kerning(0.8)
            .foregroundStyle(NibStyle.Palette.inkFaint)
    }
}

/// The mockup's `.grouped` list surface — an inset card with hairline rows.
struct GroupedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(NibStyle.Palette.surface, in: RoundedRectangle(cornerRadius: NibStyle.Metrics.cornerRadius))
    }
}

struct GroupedRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var showsDivider: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NibStyle.Typography.body(15))
                        .foregroundStyle(NibStyle.Palette.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(NibStyle.Typography.body(12))
                            .foregroundStyle(NibStyle.Palette.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if showsDivider {
                Rectangle()
                    .fill(NibStyle.Palette.divider)
                    .frame(height: 1)
                    .padding(.leading, 14)
            }
        }
    }
}

extension GroupedRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, showsDivider: Bool = true) {
        self.init(title: title, subtitle: subtitle, showsDivider: showsDivider) { EmptyView() }
    }
}

// NibChip lives in NibKit — the keyboard extension renders it too.

/// Red checkmark bullet used across the onboarding screens.
struct CheckBullet: View {
    let text: String
    var tint: Color = NibStyle.Palette.red

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .padding(.top, 2)
            Text(.init(text))
                .font(NibStyle.Typography.body(14))
                .foregroundStyle(NibStyle.Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// Screen background + standard horizontal padding.
struct NibScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            NibStyle.Palette.paper.ignoresSafeArea()
            content
        }
    }
}
