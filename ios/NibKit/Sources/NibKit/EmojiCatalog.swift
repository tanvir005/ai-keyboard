import Foundation

/// The emoji page's contents.
///
/// A curated set rather than the whole of Unicode. The extension runs under a
/// tight memory ceiling, and a full catalogue would mean either a bundled data
/// file or thousands of literals — for a page people use to find a handful of
/// faces they already have in mind. Ordered roughly by how often each one gets
/// typed, so the useful ones are reachable without scrolling.
public enum EmojiCatalog {

    public struct Category: Identifiable, Hashable {
        public let id: String
        /// The tab's own glyph, drawn from its contents. Kept as documentation
        /// of what the category is for; the tab bar draws `icon`.
        public let symbol: String
        /// SF Symbol for the tab. Both stock keyboards tab their categories
        /// with monochrome line symbols — a row of full-colour emoji competes
        /// with the grid it is meant to be navigating.
        public let icon: String
        public let emoji: [String]

        public init(id: String, symbol: String, icon: String, emoji: [String]) {
            self.id = id
            self.symbol = symbol
            self.icon = icon
            self.emoji = emoji
        }
    }

    public static let categories: [Category] = [
        Category(id: "Smileys", symbol: "😀", icon: "face.smiling", emoji: [
            "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
            "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙",
            "😋", "😛", "😜", "🤪", "😝", "🤗", "🤭", "🤔", "🤐", "😐",
            "😑", "😶", "😏", "😒", "🙄", "😬", "😔", "😪", "🤤", "😴",
            "😷", "🤒", "🤕", "🥵", "🥶", "😵", "🤯", "🤠", "🥳", "😎",
            "🤓", "🧐", "😕", "😟", "🙁", "😮", "😯", "😲", "😳", "🥺",
            "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣",
            "😞", "😓", "😩", "😫", "🥱", "😤", "😡", "😠", "🤬", "😈",
        ]),
        Category(id: "People", symbol: "👋", icon: "hand.wave", emoji: [
            "👋", "🤚", "🖐", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞",
            "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👍", "👎",
            "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏",
            "💪", "🦵", "🦶", "👂", "👃", "🧠", "👀", "👁", "👅", "👄",
            "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
            "🙋", "🤦", "🤷", "💁", "🙇", "🕺", "💃", "👫", "👪", "🫂",
        ]),
        Category(id: "Nature", symbol: "🐶", icon: "leaf", emoji: [
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
            "🦁", "🐮", "🐷", "🐸", "🐵", "🙈", "🙉", "🙊", "🐔", "🐧",
            "🐦", "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄",
            "🐝", "🐛", "🦋", "🐌", "🐞", "🐢", "🐍", "🐙", "🦀", "🐠",
            "🐟", "🐬", "🐳", "🦈", "🐊", "🐘", "🦒", "🦓", "🐫", "🐑",
            "🌵", "🌲", "🌳", "🌴", "🌱", "🌿", "☘️", "🍀", "🍁", "🍂",
            "🌸", "💐", "🌹", "🌺", "🌻", "🌼", "🌷", "🌍", "🌙", "⭐️",
            "🌟", "✨", "⚡️", "🔥", "🌈", "☀️", "⛅️", "☁️", "❄️", "💧",
        ]),
        Category(id: "Food", symbol: "🍎", icon: "fork.knife", emoji: [
            "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈",
            "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🥑", "🍆", "🥕",
            "🌽", "🌶", "🥒", "🥬", "🥦", "🧄", "🧅", "🥔", "🍞", "🥐",
            "🥖", "🧀", "🥚", "🍳", "🥞", "🧇", "🥓", "🍔", "🍟", "🍕",
            "🌭", "🥪", "🌮", "🌯", "🥗", "🍝", "🍜", "🍲", "🍣", "🍱",
            "🍚", "🍛", "🍦", "🍩", "🍪", "🎂", "🍰", "🧁", "🍫", "🍬",
            "☕️", "🍵", "🧃", "🥤", "🍺", "🍻", "🥂", "🍷", "🥃", "🍾",
        ]),
        Category(id: "Activity", symbol: "⚽️", icon: "figure.run", emoji: [
            "⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🏉", "🎱", "🏓", "🏸",
            "🥅", "🏒", "🏑", "🥍", "🏏", "⛳️", "🏹", "🎣", "🥊", "🥋",
            "⛸", "🎿", "🛷", "🏂", "🏋️", "🤸", "🤺", "⛹️", "🤾", "🏌️",
            "🏇", "🧘", "🏄", "🏊", "🚴", "🚵", "🎽", "🏆", "🥇", "🥈",
            "🥉", "🏅", "🎖", "🎗", "🎫", "🎟", "🎪", "🎭", "🎨", "🎬",
            "🎤", "🎧", "🎼", "🎹", "🥁", "🎷", "🎺", "🎸", "🎻", "🎲",
        ]),
        Category(id: "Travel", symbol: "🚗", icon: "car", emoji: [
            "🚗", "🚕", "🚙", "🚌", "🚎", "🏎", "🚓", "🚑", "🚒", "🚐",
            "🛻", "🚚", "🚛", "🚜", "🛵", "🏍", "🛺", "🚲", "🛴", "🚨",
            "🚔", "🚍", "🚝", "🚄", "🚅", "🚈", "🚂", "🚆", "🚇", "🚊",
            "✈️", "🛫", "🛬", "🪂", "💺", "🚁", "🚀", "🛸", "🛶", "⛵️",
            "🚤", "🛥", "🛳", "⛴", "🚢", "⚓️", "🗺", "🗿", "🗽", "🗼",
            "🏰", "🏯", "🏟", "🎡", "🎢", "🎠", "⛲️", "⛱", "🏖", "🏝",
            "🏔", "⛰", "🌋", "🗻", "🏕", "⛺️", "🏠", "🏡", "🏢", "🏥",
        ]),
        Category(id: "Objects", symbol: "💡", icon: "lightbulb", emoji: [
            "⌚️", "📱", "💻", "⌨️", "🖥", "🖨", "🖱", "💽", "💾", "📀",
            "📷", "📸", "📹", "🎥", "📞", "☎️", "📟", "📠", "📺", "📻",
            "⏰", "⏱", "⏲", "🕰", "⌛️", "⏳", "📡", "🔋", "🔌", "💡",
            "🔦", "🕯", "🧯", "🛢", "💸", "💵", "💴", "💶", "💷", "💰",
            "💳", "💎", "⚖️", "🧰", "🔧", "🔨", "⚒", "🛠", "⛏", "🔩",
            "⚙️", "🧱", "⛓", "🧲", "🔫", "💣", "🧨", "🔪", "🗡", "🛡",
            "🚬", "⚰️", "🏺", "🔮", "📿", "💈", "⚗️", "🔭", "🔬", "🕳",
            "💊", "💉", "🩹", "🩺", "🌡", "🧬", "🦠", "🧫", "🧪", "🧹",
            "📚", "📖", "📝", "✏️", "🖊", "🖌", "📎", "📌", "📍", "✂️",
        ]),
        Category(id: "Symbols", symbol: "❤️", icon: "heart", emoji: [
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
            "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💯", "💢",
            "💥", "💫", "💦", "💨", "🕳", "💬", "💭", "🗯", "♠️", "♥️",
            "♦️", "♣️", "🃏", "🀄️", "🎴", "✅", "❌", "❎", "➕", "➖",
            "➗", "✖️", "♾", "‼️", "⁉️", "❓", "❔", "❕", "❗️", "〰️",
            "🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "⚫️", "⚪️", "🟤", "🔺",
            "🔻", "🔶", "🔷", "🔸", "🔹", "🔘", "🔳", "🔲", "▪️", "▫️",
        ]),
    ]

    /// Flat list, for callers that do not care about the tabs.
    public static var all: [String] {
        categories.flatMap(\.emoji)
    }
}
