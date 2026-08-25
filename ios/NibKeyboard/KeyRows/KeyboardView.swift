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
    var onPress: (KeyCap) -> Void
    var onHoldBegin: (KeyCap) -> Void
    var onHoldEnd: (KeyCap) -> Void

    private let rowSpacing: CGFloat = 8
    private let keySpacing: CGFloat = 6

    /// Breathing room at the board's edges. Most of why the layout read as
    /// having none was the nine-key row running flush to both sides — see
    /// `isInsetRow`.
    private let sideInset: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let rows = KeyboardLayout.rows(for: mode, shifted: shifted)
            VStack(spacing: rowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: keySpacing) {
                        ForEach(Array(row.enumerated()), id: \.offset) { index, cap in
                            KeyButton(
                                cap: cap,
                                isActive: cap == .shift && shifted,
                                width: width(for: cap, in: row, totalWidth: geo.size.width),
                                previewAnchor: previewAnchor(at: index, in: row),
                                onPress: { onPress(cap) },
                                onHoldBegin: { onHoldBegin(cap) },
                                onHoldEnd: { onHoldEnd(cap) },
                                action: { onKey(cap) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, sideInset)
            .padding(.vertical, 6)
        }
    }

    /// Distributes the row's width by each key's relative units, so wide keys
    /// (shift, space, return) stay proportional at any screen size.
    private func width(for cap: KeyCap, in row: [KeyCap], totalWidth: CGFloat) -> CGFloat {
        let available = totalWidth - sideInset * 2
        guard available > 0 else { return 0 }

        // The inset row borrows the ten-key row's key width rather than
        // computing its own. The half key it then does not use falls either
        // side as the indent, and its letters line up with the row above.
        if isInsetRow(row) {
            return max((available - keySpacing * 9) / 10, 0)
        }

        let totalUnits = row.reduce(0) { $0 + $1.widthUnits }
        let usable = available - keySpacing * CGFloat(row.count - 1)
        guard totalUnits > 0, usable > 0 else { return 0 }
        return usable * (cap.widthUnits / totalUnits)
    }

    /// `asdfghjkl` — the only nine-letter row on any page.
    ///
    /// It used to stretch across the full width, making its keys ~11% wider
    /// than the ten above and lining up with nothing. Every other row, function
    /// keys included, still fills the board.
    private func isInsetRow(_ row: [KeyCap]) -> Bool {
        guard row.count == 9 else { return false }
        return row.allSatisfy {
            if case .character = $0 { return true }
            return false
        }
    }

    /// The balloon is wider than the key it belongs to, so the outermost keys
    /// pin it to their own edge. Centred, `Q`'s balloon would hang off the side
    /// of the input view and be clipped in half.
    private func previewAnchor(at index: Int, in row: [KeyCap]) -> Alignment {
        if index == 0 { return .topLeading }
        if index == row.count - 1 { return .topTrailing }
        return .top
    }
}

/// A single key.
///
/// Both feedback channels fire on touch-*down*, not on release. That ordering is
/// the whole point: a confirmation that arrives after you have already lifted
/// your finger reads as lag, which is why typing felt dead even though every
/// keystroke was landing correctly.
struct KeyButton: View {
    let cap: KeyCap
    var isActive: Bool = false
    let width: CGFloat
    var previewAnchor: Alignment = .top
    var onPress: () -> Void
    var onHoldBegin: () -> Void
    var onHoldEnd: () -> Void
    var action: () -> Void

    static let height: CGFloat = 42

    @State private var isPressed = false

    var body: some View {
        Text(cap.label)
            .font(labelFont)
            .foregroundStyle(isActive ? Color(hex: 0xFBF3E8) : NibStyle.Palette.ink)
            .frame(width: width, height: Self.height)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(fill)
                    .overlay {
                        // Keys with no balloon have to react in place, or shift,
                        // delete and space stay visually inert under the finger.
                        if isPressed, !showsBalloon {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(NibStyle.Palette.ink.opacity(0.16))
                        }
                    }
                    .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
            }
            .scaleEffect(isPressed && !showsBalloon ? 0.96 : 1)
            .overlay(alignment: previewAnchor) {
                if isPressed, showsBalloon {
                    KeyPreview(label: cap.label, keyWidth: width)
                        .offset(y: -KeyPreview.lift)
                }
            }
            .zIndex(isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.07), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPress()
                        // A repeating key has to act on touch-down: waiting for
                        // release means a hold does nothing at all until you
                        // let go, which is exactly how delete used to behave.
                        if cap.repeatsWhenHeld {
                            action()
                            onHoldBegin()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        if cap.repeatsWhenHeld {
                            onHoldEnd()
                        } else {
                            action()
                        }
                    }
            )
    }

    /// Characters only — the same rule Apple applies. Shift, delete, space and
    /// return are never hidden by your fingertip, so a balloon would be noise.
    private var showsBalloon: Bool {
        if case .character = cap { return true }
        return false
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

/// The press balloon — the character lifted clear of the finger covering it.
///
/// Apple draws theirs above the keyboard's top edge, over the host app. An
/// extension cannot: the input view clips at its own bounds. So this is sized
/// to fit *inside* the keyboard (48pt, against the 50pt of toolbar and padding
/// above the top key row), which is why a top-row balloon briefly overlaps the
/// tool chips. That overlap is the cost of staying inside the bounds we have.
struct KeyPreview: View {
    let label: String
    let keyWidth: CGFloat

    static let balloonHeight: CGFloat = 38
    static let neckHeight: CGFloat = 10

    /// How far above its key the balloon sits. The neck is drawn slightly
    /// longer than this so it tucks under the key's rounded top and leaves no
    /// seam.
    static var lift: CGFloat { balloonHeight + neckHeight }

    private var balloonWidth: CGFloat { max(keyWidth + 16, 40) }

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(NibStyle.Palette.ink)
                .frame(width: balloonWidth, height: Self.balloonHeight)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(NibStyle.Palette.key)
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                }

            Rectangle()
                .fill(NibStyle.Palette.key)
                .frame(width: max(keyWidth - 8, 16), height: Self.neckHeight + 4)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
