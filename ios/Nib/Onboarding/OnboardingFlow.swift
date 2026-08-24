import SwiftUI
import NibKit

/// Meet Nib → Your AI Toolkit → Turn on Nib → Switch to Nib → Allow Full Access.
struct OnboardingFlow: View {
    @Environment(SharedSettings.self) private var settings
    @State private var step: Step = .welcome

    enum Step: Int, CaseIterable {
        case welcome, toolkit, turnOn, switchTo, fullAccess
    }

    var body: some View {
        NibScreen {
            Group {
                switch step {
                case .welcome:
                    WelcomeView(onContinue: { advance(to: .toolkit) }, onSkip: finish)
                case .toolkit:
                    AIToolkitIntroView(onContinue: { advance(to: .turnOn) })
                case .turnOn:
                    TurnOnNibView(onContinue: { advance(to: .switchTo) })
                case .switchTo:
                    SwitchToNibEducationView(onContinue: { advance(to: .fullAccess) })
                case .fullAccess:
                    FullAccessExplainerView(onDone: finish)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(.snappy(duration: 0.28), value: step)
    }

    private func advance(to next: Step) { step = next }

    private func finish() { settings.onboardingComplete = true }
}

/// Two-dot page indicator from the first two screens.
struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? NibStyle.Palette.red : NibStyle.Palette.kraftCardLine)
                    .frame(width: i == index ? 18 : 7, height: 7)
            }
        }
    }
}
