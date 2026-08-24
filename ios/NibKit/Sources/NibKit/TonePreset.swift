import Foundation

/// A tone the Tone tool can rewrite into.
///
/// Built-ins can't be deleted; custom ones are created on the Presets screen
/// and carry a freeform instruction that the backend folds into the prompt.
public struct TonePreset: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    /// Freeform instruction for custom presets. Empty for built-ins, whose
    /// behaviour the backend already knows by name.
    public var instruction: String
    public let isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, instruction: String = "", isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.isBuiltIn = isBuiltIn
    }

    // Stable ids so a preset selected in the keyboard resolves in the host app.
    public static let professional = TonePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Professional", isBuiltIn: true
    )
    public static let friendly = TonePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Friendly", isBuiltIn: true
    )
    public static let concise = TonePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Concise", isBuiltIn: true
    )
    /// Shown in the mockup's keyboard sub-chip row alongside Professional/Shorter.
    public static let warmer = TonePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Warmer", isBuiltIn: true
    )

    public static let builtIns: [TonePreset] = [.professional, .friendly, .concise, .warmer]
}
