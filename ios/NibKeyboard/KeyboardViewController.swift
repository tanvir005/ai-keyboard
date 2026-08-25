import UIKit
import SwiftUI
import NibKit

/// The keyboard extension's entry point.
///
/// Responsibilities are deliberately thin: own the lifecycle, adapt
/// `UITextDocumentProxy` to `KeyboardTextInterface`, and host the SwiftUI tree.
/// All product logic lives in `ToolbarViewModel`; all prompt construction will
/// live server-side. This process runs under a tight memory ceiling, so
/// resist adding dependencies here — no analytics, no crash SDK, no HTTP lib.
final class KeyboardViewController: UIInputViewController {

    private var model: ToolbarViewModel!
    private var host: UIHostingController<KeyboardRootView>!
    private var heightConstraint: NSLayoutConstraint?

    /// Held rather than created per keystroke: the Taptic Engine needs warming,
    /// and a generator built at press time fires late enough to feel detached
    /// from the tap.
    private let impact = UIImpactFeedbackGenerator(style: .light)

    override func viewDidLoad() {
        super.viewDidLoad()

        model = ToolbarViewModel(text: self)

        let root = KeyboardRootView(
            model: model,
            onKey: { [weak self] in self?.handle($0) },
            onPress: { [weak self] in self?.feedback(for: $0) },
            onHeightChange: { [weak self] in self?.updateHeight($0) }
        )

        host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let height = view.heightAnchor.constraint(equalToConstant: 258)
        // Below required so the system can still resize us without conflicts.
        height.priority = .defaultHigh
        height.isActive = true
        heightConstraint = height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The host app cannot read this itself — record it so Settings can
        // report Full Access state honestly, as of the last keyboard use.
        SharedSettings.shared.recordFullAccess(hasFullAccess)

        if SharedSettings.shared.hapticsEnabled, hasFullAccess {
            impact.prepare()
        }
    }

    private func updateHeight(_ height: CGFloat) {
        guard height > 0, let constraint = heightConstraint else { return }
        guard abs(constraint.constant - height) > 1 else { return }
        constraint.constant = height
    }

    // MARK: - Press feedback

    /// Fires on touch-down, before the character is inserted.
    ///
    /// Both channels are gated on their Settings toggle. Haptics are gated on
    /// Full Access too: `UIFeedbackGenerator` is inert in an extension without
    /// it, so there is nothing to gain from warming the engine.
    private func feedback(for cap: KeyCap) {
        if SharedSettings.shared.soundEnabled {
            UIDevice.current.playInputClick()
        }

        if SharedSettings.shared.hapticsEnabled, hasFullAccess {
            impact.impactOccurred(intensity: 0.65)
            impact.prepare()
        }
    }

    // MARK: - Key handling

    private func handle(_ cap: KeyCap) {
        switch cap {
        case .character(let c):
            textDocumentProxy.insertText(c)
        case .space:
            textDocumentProxy.insertText(" ")
        case .newline:
            textDocumentProxy.insertText("\n")
        case .backspace:
            textDocumentProxy.deleteBackward()
        case .globe:
            advanceToNextInputMode()
        case .shift, .mode:
            break // handled in the SwiftUI layer, which owns that state
        }
    }
}

// MARK: - Audio feedback

/// Without this conformance `playInputClick()` is silently discarded: the
/// system asks the input view whether it wants clicks, and the default answer
/// is no. This is why the Sound toggle in Settings appeared to do nothing.
extension KeyboardViewController: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

// MARK: - KeyboardTextInterface

extension KeyboardViewController: KeyboardTextInterface {
    var documentBefore: String? { textDocumentProxy.documentContextBeforeInput }
    var documentAfter: String? { textDocumentProxy.documentContextAfterInput }

    func insertText(_ text: String) { textDocumentProxy.insertText(text) }
    func deleteBackward() { textDocumentProxy.deleteBackward() }
}

// MARK: - Root view

struct KeyboardRootView: View {
    @Bindable var model: ToolbarViewModel
    var onKey: (KeyCap) -> Void
    var onPress: (KeyCap) -> Void
    var onHeightChange: (CGFloat) -> Void

    @State private var mode: KeyboardMode = .letters
    @State private var shifted = true

    private let keyAreaHeight: CGFloat = 214

    var body: some View {
        VStack(spacing: 0) {
            AccessoryBarView(model: model)
            KeyboardView(mode: mode, shifted: shifted, onKey: handle, onPress: onPress)
                .frame(height: keyAreaHeight)
        }
        .background(NibStyle.Palette.keyboardBackground)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: KeyboardHeightKey.self, value: geo.size.height)
            }
        }
        .onPreferenceChange(KeyboardHeightKey.self) { onHeightChange($0) }
    }

    /// Shift and page switching are view state; everything else is a document
    /// edit and goes to the controller.
    private func handle(_ cap: KeyCap) {
        switch cap {
        case .shift:
            shifted.toggle()
        case .mode(let next):
            mode = next
            shifted = next == .letters
        case .character:
            onKey(cap)
            if shifted { shifted = false } // auto-unshift, like the system keyboard
        default:
            onKey(cap)
        }
    }
}

private struct KeyboardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
