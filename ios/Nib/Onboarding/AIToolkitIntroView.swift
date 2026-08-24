import SwiftUI
import NibKit

/// Screen 2 — "Your AI Toolkit".
///
/// The mockup shows seven tools. Reply is cut from v1 (a keyboard extension
/// cannot read the other person's message), so this renders the six that ship:
/// five in a grid, Ask AI full-width beneath, matching the mockup's layout.
struct AIToolkitIntroView: View {
    var onContinue: () -> Void

    private var gridTools: [NibTool] { NibTool.allCases.filter { $0 != .ask } }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Everything Nib can do")
                    .font(NibStyle.Typography.display(24))
                    .foregroundStyle(NibStyle.Palette.ink)
                Text("One toolbar. No separate apps.")
                    .font(NibStyle.Typography.body(14))
                    .foregroundStyle(NibStyle.Palette.inkSoft)
            }
            .padding(.top, 44)

            ScrollView {
                // Explicit VStack: ScrollView's ViewBuilder does not stack
                // sibling views for you.
                VStack(spacing: 10) {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(gridTools) { tool in
                            ToolCard(tool: tool)
                        }
                    }
                    ToolCard(tool: .ask) // full width by virtue of sitting outside the grid
                }
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, NibStyle.Metrics.screenPadding)
            .padding(.top, 26)

            NibPrimaryButton(title: "Set up Nib", action: onContinue)
                .padding(.horizontal, NibStyle.Metrics.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 12)
        }
    }
}

private struct ToolCard: View {
    let tool: NibTool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: tool.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NibStyle.Palette.red)
            Text(tool.title)
                .font(NibStyle.Typography.body(14, weight: .semibold))
                .foregroundStyle(NibStyle.Palette.ink)
            Text(tool.subtitle)
                .font(NibStyle.Typography.body(12))
                .foregroundStyle(NibStyle.Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(NibStyle.Palette.surface, in: RoundedRectangle(cornerRadius: NibStyle.Metrics.cornerRadius))
    }
}
