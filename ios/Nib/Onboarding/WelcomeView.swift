import SwiftUI
import NibKit

/// Screen 1 — "Meet Nib".
struct WelcomeView: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onSkip)
                    .font(NibStyle.Typography.body(15))
                    .foregroundStyle(NibStyle.Palette.inkFaint)
            }
            .padding(.horizontal, NibStyle.Metrics.screenPadding)
            .padding(.top, 8)

            Spacer()

            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0xEFE6CC))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(NibStyle.Palette.red)
                }

            Text("Type less. Say more.")
                .font(NibStyle.Typography.display(28))
                .foregroundStyle(NibStyle.Palette.ink)
                .padding(.top, 26)

            Text("Nib rewrites, fixes tone, and translates what you type — right where you type it.")
                .font(NibStyle.Typography.body(15))
                .foregroundStyle(NibStyle.Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 34)

            Spacer()

            PageDots(count: 2, index: 0)
                .padding(.bottom, 22)

            NibPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, NibStyle.Metrics.screenPadding)
                .padding(.bottom, 12)
        }
    }
}
