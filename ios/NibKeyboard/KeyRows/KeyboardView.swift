import SwiftUI
import NibKit

/// The key grid.
///
/// Rendered by us, because iOS gives a keyboard extension no access to the
/// system layout — the extension replaces the keyboard wholesale, it does not
/// overlay the stock one.
struct KeyboardView: View {
    let mode: KeyboardMode
    let shifted: Bool
    var onKey: (KeyCap) -> Void

    private let rowSpacing: CGFloat = 8
    private let keySpacing: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let rows = KeyboardLayout.rows(for: mode, shifted: shifted)
            VStack(spacing: rowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: keySpacing) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cap in
                            KeyButton(
                                cap: cap,
                                isActive: cap == .shift && shifted,
                                width: width(for: cap, in: row, totalWidth: geo.size.width)
                            ) {
                                onKey(cap)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }

    /// Distributes the row's width by each key's relative units, so wide keys
    /// (shift, space, return) stay proportional at any screen size.
    private func width(for cap: KeyCap, in row: [KeyCap], totalWidth: CGFloat) -> CGFloat {
        let totalUnits = row.reduce(0) { $0 + $1.widthUnits }
        let spacing = keySpacing * CGFloat(row.count - 1)
        let available = totalWidth - spacing - 8
        guard totalUnits > 0, available > 0 else { return 0 }
        return available * (cap.widthUnits / totalUnits)
    }
}

struct KeyButton: View {
    let cap: KeyCap
    var isActive: Bool = false
    let width: CGFloat
    var action: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        Text(cap.label)
            .font(labelFont)
            .foregroundStyle(isActive ? Color(hex: 0xFBF3E8) : NibStyle.Palette.ink)
            .frame(width: width, height: 42)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(fill)
                    .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
            }
            .scaleEffect(isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
                    .onEnded { _ in action() }
            )
    }

    private var fill: Color {
        if isActive { return NibStyle.Palette.red }
        if case .newline = cap { return NibStyle.Palette.red.opacity(0.85) }
        return cap.isFunction ? NibStyle.Palette.keyWide : NibStyle.Palette.key
    }

    private var labelFont: Font {
        switch cap {
        case .character: .system(size: 21, weight: .regular)
        case .space, .mode: .system(size: 13, weight: .medium)
        default: .system(size: 16, weight: .medium)
        }
    }
}
