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
    /// What the return key says in this field — "Send" in Messages, "Go" in
    /// Safari. Only the controller can see the host app's `returnKeyType`.
    var returnLabel: String = "return"
    /// False when iOS draws its own keyboard switcher below us, which is the
    /// usual case. See `KeyboardLayout.bottomRow`.
    var needsGlobe: Bool = false
    var onKey: (KeyCap) -> Void
    var onPress: (KeyCap) -> Void
    var onHoldBegin: (KeyCap) -> Void
    var onHoldEnd: (KeyCap) -> Void
    var onAlternate: (String) -> Void
    var onCursorBegin: () -> Void
    var onCursorMove: (Int) -> Void

    private let rowSpacing: CGFloat = 8
    private let topInset: CGFloat = 18
    private let bottomInset: CGFloat = 6
    private let keySpacing: CGFloat = 6

    /// Breathing room at the board's edges. Most of why the layout read as
    /// having none was the nine-key row running flush to both sides — see
    /// `isInsetRow`.
    private let sideInset: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let rows = KeyboardLayout.rows(for: mode, shifted: shifted, needsGlobe: needsGlobe)
            let keyHeight = keyHeight(forBoardHeight: geo.size.height, rows: rows.count)
            VStack(spacing: rowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    let widths = row.map { width(for: $0, in: row, totalWidth: geo.size.width) }
                    // Rows are centred by the VStack, so the inset row's origin
                    // is not the board's edge — the alternates row has to be
                    // placed against the board, not against the key.
                    let rowOrigin = (geo.size.width - rowWidth(widths)) / 2

                    HStack(spacing: keySpacing) {
                        ForEach(Array(row.enumerated()), id: \.offset) { index, cap in
                            KeyButton(
                                cap: cap,
                                isActive: cap == .shift && shifted,
                                width: widths[index],
                                height: keyHeight,
                                previewAnchor: previewAnchor(at: index, in: row),
                                keyCenterX: centerX(at: index, widths: widths, rowOrigin: rowOrigin),
                                boardWidth: geo.size.width,
                                boardInset: sideInset,
                                hitSlop: hitSlop(
                                    row: rowIndex,
                                    of: rows.count,
                                    column: index,
                                    of: row.count
                                ),
                                onPress: { onPress(cap) },
                                onHoldBegin: { onHoldBegin(cap) },
                                onHoldEnd: { onHoldEnd(cap) },
                                onAlternate: onAlternate,
                                onCursorBegin: onCursorBegin,
                                onCursorMove: onCursorMove,
                                labelOverride: labelOverride(for: cap),
                                action: { onKey(cap) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, sideInset)
            // Asymmetric on purpose: the top row's balloon is drawn upward into
            // this gap, and the input view clips at its own edge. Without the
            // headroom the balloon cannot grow to the size a thumb-covered key
            // actually needs.
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
        }
    }

    /// How far a key's touch area reaches past its own edges.
    ///
    /// Half the gap on any side with a neighbour, so the gaps between keys
    /// belong to the nearer of the two. Nothing at all on the outside edges —
    /// the board's margin belongs to no key, and the strip under the bottom
    /// row is the one a thumb finds by accident.
    private func hitSlop(row: Int, of rowCount: Int, column: Int, of columnCount: Int) -> EdgeInsets {
        EdgeInsets(
            top: row == 0 ? 0 : rowSpacing / 2,
            leading: column == 0 ? 0 : keySpacing / 2,
            bottom: row == rowCount - 1 ? 0 : rowSpacing / 2,
            trailing: column == columnCount - 1 ? 0 : keySpacing / 2
        )
    }

    /// Key height, from whatever room the board actually got.
    ///
    /// Fixed at 42 it fits — until the toolbar above grows a title row for a
    /// selected tool, at which point the total exceeds the input view and the
    /// bottom row is simply cut off the screen, unreachable. Keys a few points
    /// shorter are a far smaller cost than a return key nobody can press, so
    /// the height gives way rather than the layout breaking.
    private func keyHeight(forBoardHeight height: CGFloat, rows: Int) -> CGFloat {
        guard rows > 0 else { return KeyButton.height }

        let spacing = rowSpacing * CGFloat(rows - 1)
        let available = height - topInset - bottomInset - spacing
        guard available > 0 else { return KeyButton.minimumHeight }

        return min(KeyButton.height, max(KeyButton.minimumHeight, available / CGFloat(rows)))
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

    /// Only the return key is relabelled, and only when the field asks for it.
    private func labelOverride(for cap: KeyCap) -> String? {
        if case .newline = cap { return returnLabel }
        return nil
    }

    private func rowWidth(_ widths: [CGFloat]) -> CGFloat {
        widths.reduce(0, +) + keySpacing * CGFloat(max(widths.count - 1, 0))
    }

    /// A key's centre in the board's coordinate space, which is what the
    /// alternates row needs in order to clamp itself inside the edges.
    private func centerX(at index: Int, widths: [CGFloat], rowOrigin: CGFloat) -> CGFloat {
        let preceding = widths.prefix(index).reduce(0, +) + keySpacing * CGFloat(index)
        return rowOrigin + preceding + widths[index] / 2
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

/// A key's touch area: its own rectangle, grown only on the sides where a
/// neighbouring key sits.
///
/// Growing on those sides means the gaps between keys belong to somebody, so a
/// thumb landing on a boundary still types rather than falling down a crack.
/// Not growing at the board's edges matters just as much: there is no
/// neighbour out there to disambiguate, only margin — and a margin that clicks
/// is a keyboard reporting a keystroke nobody made. The strip under the space
/// bar is the one people find.
private struct KeyHitArea: Shape {
    let insets: EdgeInsets

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX - insets.leading,
            y: rect.minY - insets.top,
            width: rect.width + insets.leading + insets.trailing,
            height: rect.height + insets.top + insets.bottom
        ))
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
    var height: CGFloat = KeyButton.height
    var previewAnchor: Alignment = .top
    var keyCenterX: CGFloat = 0
    var boardWidth: CGFloat = 0
    var boardInset: CGFloat = 6
    /// How far this key's touch area reaches past its own edges — half the gap
    /// on any side with a neighbour, nothing on any side facing the board's
    /// margin. See `KeyHitArea`.
    var hitSlop = EdgeInsets()
    var onPress: () -> Void
    var onHoldBegin: () -> Void
    var onHoldEnd: () -> Void
    var onAlternate: (String) -> Void
    var onCursorBegin: () -> Void
    var onCursorMove: (Int) -> Void
    /// Replaces the cap's own label. Used for the return key, whose text
    /// belongs to the field being typed into rather than to the layout.
    var labelOverride: String?
    var action: () -> Void

    /// The height a key wants. `KeyboardView` passes what it can actually give.
    static let height: CGFloat = 42
    /// Below this a key stops being reliably hittable.
    static let minimumHeight: CGFloat = 32
    static let alternateItemWidth: CGFloat = 38
    static let alternateItemHeight: CGFloat = 46
    static let alternatePadding: CGFloat = 4

    /// How far the finger travels per character while the space bar is acting
    /// as a trackpad. Roughly a third of a key width — small enough to reach
    /// the other end of a sentence, large enough not to overshoot by one.
    static let cursorStep: CGFloat = 10

    @State private var isPressed = false
    @State private var pressInside = true
    @State private var showingAlternates = false
    @State private var selectedAlternate = 0

    @State private var cursorMode = false
    @State private var cursorOriginX: CGFloat = 0
    @State private var cursorSteps = 0
    @State private var lastTouchX: CGFloat = 0

    var body: some View {
        keyLabel
            .foregroundStyle(isActive ? NibStyle.Palette.onAccent : NibStyle.Palette.keyLabel)
            .frame(width: width, height: height)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(fill)
                    .overlay {
                        // Keys with no balloon have to react in place, or shift,
                        // delete and space stay visually inert under the finger.
                        if isPressed, pressInside, !showsBalloon {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(NibStyle.Palette.keyLabel.opacity(0.16))
                        }
                    }
                    .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
            }
            .scaleEffect(isPressed && pressInside && !showsBalloon ? 0.96 : 1)
            .overlay(alignment: previewAnchor) {
                if isPressed, pressInside, showsBalloon, !showingAlternates {
                    KeyPreview(label: cap.label, keyWidth: width)
                        .offset(y: -KeyPreview.lift)
                }
            }
            .overlay(alignment: .top) {
                if showingAlternates {
                    alternatesRow
                        .offset(x: alternatesOffsetX, y: -alternatesLift)
                }
            }
            .zIndex(isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.07), value: isPressed)
            // Says exactly what counts as touching this key, rather than
            // leaving it to whatever SwiftUI infers from the label plus the
            // slop iOS adds around small targets. Without it a tap in the gap
            // between two keys was ambiguous: near enough to trigger the click
            // and the tap, not always near enough to type anything — feedback
            // reporting a keystroke that never happened.
            //
            // Expanded by half the gap so the gaps belong to the nearest key,
            // which is what the stock keyboard does and why its edges never
            // feel dead. Nothing outside the rows responds at all.
            .contentShape(KeyHitArea(insets: hitSlop))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        lastTouchX = value.location.x

                        if cursorMode {
                            // The whole board is the trackpad once it opens —
                            // a caret dragged only as far as the space bar is
                            // wide would barely cross a word.
                            let travelled = value.location.x - cursorOriginX
                            let steps = Int((travelled / Self.cursorStep).rounded(.towardZero))
                            if steps != cursorSteps {
                                onCursorMove(steps - cursorSteps)
                                cursorSteps = steps
                            }
                            return
                        }

                        // Shown live so a cancel is visible: slide off and the
                        // balloon goes with it, rather than the keystroke
                        // vanishing with no explanation.
                        pressInside = TypingRules.releaseCommitsKey(
                            location: value.location,
                            size: CGSize(width: width, height: height)
                        )

                        if !isPressed {
                            // Where the touch actually *began*, measured against
                            // this key rather than trusted to whatever routed
                            // the gesture here. Declaring the hit area was meant
                            // to keep the board's margins quiet and did not, so
                            // this asks the one question that cannot be answered
                            // wrong: is the finger on the key or not?
                            //
                            // Strict, unlike the release check below. Starting a
                            // touch is a decision; finishing one is a wobble, and
                            // deserves more room.
                            guard startedOnKey(value.location) else { return }

                            isPressed = true
                            onPress()
                            // A repeating key has to act on touch-down: waiting
                            // for release means a hold does nothing at all until
                            // you let go, which is how delete used to behave.
                            if cap.repeatsWhenHeld {
                                action()
                                onHoldBegin()
                            }
                        }

                        guard showingAlternates else { return }
                        selectedAlternate = KeyAlternates.index(
                            forX: value.location.x,
                            rowLeft: alternatesFirstItemLeft,
                            itemWidth: Self.alternateItemWidth,
                            count: alternates.count
                        )
                    }
                    .onEnded { value in
                        isPressed = false

                        if cursorMode {
                            // No space is typed: the hold was a request to move
                            // the caret, not to insert anything.
                            cursorMode = false
                            cursorSteps = 0
                        } else if showingAlternates {
                            let picked = alternates[min(selectedAlternate, alternates.count - 1)]
                            showingAlternates = false
                            onAlternate(picked)
                        } else if cap.repeatsWhenHeld {
                            onHoldEnd()
                        } else if TypingRules.releaseCommitsKey(
                            location: value.location,
                            size: CGSize(width: width, height: height)
                        ) {
                            action()
                        }
                        // Released away from the key: cancelled, deliberately.
                        // Sliding off is how a keystroke is taken back.
                    }
            )
            // Simultaneous rather than sequenced: the drag has to keep tracking
            // the finger once the row is open, so it cannot be a `.sequenced`
            // chain that hands control over.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45, maximumDistance: 20)
                    .onEnded { _ in
                        // Holding space turns the board into a trackpad for the
                        // caret, the way the stock keyboard does. It is the only
                        // way to reach the middle of a sentence without lifting
                        // your hand to tap at the text.
                        if case .space = cap {
                            cursorOriginX = lastTouchX
                            cursorSteps = 0
                            cursorMode = true
                            onCursorBegin()
                            return
                        }

                        guard !alternates.isEmpty, !cap.repeatsWhenHeld else { return }
                        selectedAlternate = baseAlternateIndex
                        showingAlternates = true
                    }
            )
    }

    /// A relabelled return key is text; a function key is a symbol; everything
    /// else is its own glyph.
    @ViewBuilder
    private var keyLabel: some View {
        if let labelOverride {
            Text(labelOverride).font(labelFont)
        } else if let symbol = symbolName {
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .regular))
                .accessibilityLabel(cap.spokenLabel)
        } else {
            Text(cap.label)
                .font(labelFont)
                .accessibilityLabel(cap.spokenLabel)
        }
    }

    private var symbolName: String? {
        // Shift fills in when it is on, which is how the stock keyboard shows
        // the difference without a second colour.
        if case .shift = cap, isActive { return "shift.fill" }
        return cap.symbolName
    }

    /// Symbols are optically larger than type at the same point size, so these
    /// sit below the 21pt of a letter cap rather than matching it.
    private var symbolSize: CGFloat {
        switch cap {
        case .shift, .backspace: 19
        default: 20
        }
    }

    /// Whether a touch at `location` counts as landing on this key.
    ///
    /// Uses the same asymmetric reach as the hit area: half a gap toward a
    /// neighbouring key, nothing at all toward the board's margin. So the strip
    /// under the bottom row and the band above the top row belong to no key,
    /// and touching them does nothing.
    private func startedOnKey(_ location: CGPoint) -> Bool {
        location.x >= -hitSlop.leading
            && location.x <= width + hitSlop.trailing
            && location.y >= -hitSlop.top
            && location.y <= height + hitSlop.bottom
    }

    /// Characters only — the same rule Apple applies. Shift, delete, space and
    /// return are never hidden by your fingertip, so a balloon would be noise.
    private var showsBalloon: Bool {
        if case .character = cap { return true }
        return false
    }

    // MARK: - Alternates

    private var opensLeftward: Bool {
        KeyAlternates.opensLeftward(keyCenterX: keyCenterX, boardWidth: boardWidth)
    }

    /// Reversed when the row opens leftward, so the base glyph ends up at the
    /// end nearest its own key rather than stranded at the far side.
    private var alternates: [String] {
        guard case .character(let character) = cap else { return [] }
        let row = KeyAlternates.row(for: character)
        return opensLeftward ? row.reversed() : row
    }

    /// Where the finger starts: on the glyph already being typed.
    private var baseAlternateIndex: Int {
        opensLeftward ? max(alternates.count - 1, 0) : 0
    }

    private var alternatesWidth: CGFloat {
        Self.alternateItemWidth * CGFloat(alternates.count) + Self.alternatePadding * 2
    }

    private var alternatesLift: CGFloat {
        Self.alternateItemHeight + Self.alternatePadding * 2 + 4
    }

    /// Board-space left edge, anchored so the base glyph sits over its key.
    private var alternatesLeft: CGFloat {
        KeyAlternates.rowLeft(
            keyCenterX: keyCenterX,
            keyWidth: width,
            rowWidth: alternatesWidth,
            boardWidth: boardWidth,
            boardInset: boardInset,
            padding: Self.alternatePadding,
            opensLeftward: opensLeftward
        )
    }

    /// The overlay is centred on the key, so this is the correction that moves
    /// it to `alternatesLeft`.
    private var alternatesOffsetX: CGFloat {
        alternatesLeft + alternatesWidth / 2 - keyCenterX
    }

    /// The left edge of the first glyph, in the key's own coordinate space —
    /// which is the space `DragGesture` reports touches in.
    private var alternatesFirstItemLeft: CGFloat {
        alternatesLeft + Self.alternatePadding - (keyCenterX - width / 2)
    }

    private var alternatesRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(alternates.enumerated()), id: \.offset) { index, glyph in
                Text(glyph)
                    .font(.system(size: 22))
                    .foregroundStyle(
                        index == selectedAlternate ? NibStyle.Palette.onAccent : NibStyle.Palette.keyLabel
                    )
                    .frame(width: Self.alternateItemWidth, height: Self.alternateItemHeight)
                    .background {
                        if index == selectedAlternate {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(NibStyle.Palette.red)
                        }
                    }
            }
        }
        .padding(Self.alternatePadding)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(NibStyle.Palette.key)
                .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
        }
        .allowsHitTesting(false)
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
/// to fit *inside* the keyboard — 56pt against the 62pt of toolbar and top
/// padding above the first key row — which is why a top-row balloon briefly
/// overlaps the tool chips. That overlap is the cost of the bounds we have.
struct KeyPreview: View {
    let label: String
    let keyWidth: CGFloat

    static let balloonHeight: CGFloat = 46
    static let neckHeight: CGFloat = 10

    /// How far above its key the balloon sits. The neck is drawn slightly
    /// longer than this so it tucks under the key's rounded top and leaves no
    /// seam.
    static var lift: CGFloat { balloonHeight + neckHeight }

    /// Half a key wider on each side, which is roughly the stock keyboard's
    /// proportion. The floor matters on the symbols page, where a narrow key
    /// would otherwise get a balloon too small to read at a glance.
    private var balloonWidth: CGFloat { max(keyWidth * 1.5, 46) }

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(NibStyle.Palette.keyLabel)
                .frame(width: balloonWidth, height: Self.balloonHeight)
                .background {
                    RoundedRectangle(cornerRadius: 9)
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
