import Foundation

/// The common core of written English, most-used first.
///
/// Used only to *rank* what the system spell checker hands back. `UITextChecker`
/// returns completions and guesses with no sense of which one a person is likely
/// to have meant, so a prefix like "hel" can surface "helicoid" ahead of "hello".
/// Ranking against this list is what puts the ordinary word first.
///
/// Deliberately small. The extension runs under a tight memory ceiling, and the
/// long tail is the part that least needs ranking — anything missing here sorts
/// after everything present, which is the right answer for a rare word anyway.
public enum WordFrequency {

    /// Rank of `word`, or nil when it is not in the common core. Lower is more
    /// common.
    public static func rank(of word: String) -> Int? {
        index[word.lowercased()]
    }

    /// Sorts candidates by how ordinary they are, keeping the checker's own
    /// order among words this list does not know — it has no opinion there, and
    /// inventing one would be worse than deferring.
    public static func ranked(_ candidates: [String]) -> [String] {
        candidates.enumerated().sorted { left, right in
            let a = rank(of: left.element) ?? Int.max
            let b = rank(of: right.element) ?? Int.max
            if a != b { return a < b }
            return left.offset < right.offset
        }.map(\.element)
    }

    /// The most ordinary words starting with `prefix`, most common first.
    ///
    /// This is what the strip offers for the first letter or two of a word,
    /// where the system checker is both slow and useless: a one-letter prefix
    /// matches thousands of entries, and it hands them back in an order nobody
    /// would choose. Nine hundred common words filtered by prefix is instant,
    /// and the answer is better — the words a person actually writes.
    public static func matching(prefix: String, limit: Int = 2) -> [String] {
        let needle = prefix.lowercased()
        guard !needle.isEmpty else { return [] }

        var found: [String] = []
        // `common` is already in frequency order, so the first matches are the
        // right ones and there is nothing to sort.
        for word in common where word.hasPrefix(needle) && word != needle {
            found.append(word)
            if found.count == limit { break }
        }
        return found
    }

    private static let index: [String: Int] = {
        var map: [String: Int] = [:]
        map.reserveCapacity(common.count)
        for (rank, word) in common.enumerated() where map[word] == nil {
            map[word] = rank
        }
        return map
    }()

    static let common: [String] = [
        "the", "be", "to", "of", "and", "in", "that", "have",
        "it", "for", "not", "on", "with", "he", "as", "you",
        "do", "at", "this", "but", "his", "by", "from", "they",
        "we", "say", "her", "she", "or", "an", "will", "my",
        "one", "all", "would", "there", "their", "what", "so", "up",
        "out", "if", "about", "who", "get", "which", "go", "me",
        "when", "make", "can", "like", "time", "no", "just", "him",
        "know", "take", "people", "into", "year", "your", "good", "some",
        "could", "them", "see", "other", "than", "then", "now", "look",
        "only", "come", "its", "over", "think", "also", "back", "after",
        "use", "two", "how", "our", "work", "first", "well", "way",
        "even", "new", "want", "because", "any", "these", "give", "day",
        "most", "us", "is", "are", "was", "were", "been", "has",
        "had", "said", "did", "got", "made", "went", "im", "ive",
        "dont", "doesnt", "didnt", "cant", "wont", "isnt", "arent", "wasnt",
        "werent", "hasnt", "havent", "hadnt", "wouldnt", "couldnt", "shouldnt", "lets",
        "thats", "theres", "whats", "hes", "shes", "youre", "theyre", "ill",
        "youll", "theyll", "youve", "weve", "theyve", "hello", "help", "held",
        "hear", "heard", "heart", "heavy", "health", "healthy", "here", "thank",
        "thanks", "thing", "things", "thought", "through", "though", "those", "three",
        "throw", "please", "place", "plan", "play", "player", "pleased", "plenty",
        "message", "messages", "meet", "meeting", "member", "memory", "mention", "morning",
        "money", "month", "more", "mother", "move", "movie", "much", "music",
        "must", "number", "never", "night", "nothing", "notice", "paper", "parent",
        "park", "part", "party", "pass", "past", "pay", "peace", "perhaps",
        "period", "person", "phone", "photo", "pick", "picture", "piece", "plant",
        "point", "police", "policy", "political", "poor", "popular", "position", "possible",
        "power", "practice", "prepare", "present", "president", "press", "pretty", "prevent",
        "price", "probably", "problem", "process", "produce", "product", "program", "project",
        "property", "protect", "prove", "provide", "public", "pull", "purpose", "push",
        "question", "quick", "quickly", "quiet", "quite", "reach", "read", "ready",
        "real", "reality", "realize", "really", "reason", "receive", "recent", "recently",
        "recognize", "record", "reduce", "reflect", "region", "relate", "relationship", "religious",
        "remain", "remember", "remove", "report", "represent", "require", "research", "resource",
        "respond", "response", "responsibility", "rest", "result", "return", "reveal", "rich",
        "right", "rise", "risk", "road", "rock", "role", "room", "rule",
        "run", "safe", "same", "save", "scene", "school", "science", "score",
        "sea", "season", "seat", "second", "section", "security", "seek", "seem",
        "sell", "send", "senior", "sense", "series", "serious", "serve", "service",
        "set", "seven", "several", "shake", "share", "shoot", "short", "shot",
        "should", "shoulder", "show", "side", "sign", "significant", "similar", "simple",
        "simply", "since", "sing", "single", "sister", "sit", "site", "situation",
        "six", "size", "skill", "skin", "small", "smile", "social", "society",
        "soldier", "somebody", "someone", "something", "sometimes", "son", "song", "soon",
        "sort", "sound", "source", "south", "southern", "space", "speak", "special",
        "specific", "speech", "spend", "sport", "spring", "staff", "stage", "stand",
        "standard", "star", "start", "state", "statement", "station", "stay", "step",
        "still", "stock", "stop", "store", "story", "strategy", "street", "strong",
        "structure", "student", "study", "stuff", "style", "subject", "success", "successful",
        "such", "suddenly", "suffer", "suggest", "summer", "support", "sure", "surface",
        "system", "table", "talk", "task", "tax", "teach", "teacher", "team",
        "technology", "television", "tell", "ten", "tend", "term", "test", "text",
        "third", "thousand", "threat", "throughout", "thus", "today", "together", "tonight",
        "too", "top", "total", "tough", "toward", "town", "trade", "traditional",
        "training", "travel", "treat", "treatment", "tree", "trial", "trip", "trouble",
        "true", "truth", "try", "turn", "type", "under", "understand", "union",
        "unit", "until", "upon", "usually", "value", "various", "very", "victim",
        "view", "violence", "visit", "voice", "vote", "wait", "walk", "wall",
        "war", "watch", "water", "weapon", "wear", "week", "weight", "west",
        "western", "whatever", "where", "whether", "while", "white", "whole", "whom",
        "whose", "why", "wide", "wife", "win", "wind", "window", "wish",
        "within", "without", "woman", "wonder", "word", "worker", "world", "worry",
        "write", "writer", "wrong", "yard", "yeah", "yes", "yet", "young",
        "yourself", "above", "across", "act", "actually", "add", "address", "admit",
        "adult", "affect", "again", "against", "age", "agency", "agent", "agree",
        "agreement", "ahead", "air", "allow", "almost", "alone", "along", "already",
        "although", "always", "american", "among", "amount", "analysis", "animal", "another",
        "answer", "anyone", "anything", "appear", "apply", "approach", "area", "argue",
        "arm", "around", "arrive", "art", "article", "artist", "ask", "assume",
        "attack", "attention", "attorney", "audience", "author", "authority", "available", "avoid",
        "away", "baby", "bad", "bag", "ball", "bank", "bar", "base",
        "beat", "beautiful", "become", "bed", "before", "begin", "behavior", "behind",
        "believe", "benefit", "best", "better", "between", "beyond", "big", "bill",
        "billion", "bit", "black", "blood", "blue", "board", "body", "book",
        "born", "both", "box", "boy", "break", "bring", "brother", "budget",
        "build", "building", "business", "buy", "call", "camera", "campaign", "cancer",
        "candidate", "capital", "car", "card", "care", "career", "carry", "case",
        "catch", "cause", "cell", "center", "central", "century", "certain", "certainly",
        "chair", "challenge", "chance", "change", "character", "charge", "check", "child",
        "choice", "choose", "church", "citizen", "city", "civil", "claim", "class",
        "clear", "clearly", "close", "coach", "cold", "collection", "college", "color",
        "commercial", "common", "community", "company", "compare", "computer", "concern", "condition",
        "conference", "congress", "consider", "consumer", "contain", "continue", "control", "cost",
        "country", "couple", "course", "court", "cover", "create", "crime", "cultural",
        "culture", "cup", "current", "customer", "cut", "dark", "data", "daughter",
        "dead", "deal", "death", "debate", "decade", "decide", "decision", "deep",
        "defense", "degree", "democrat", "democratic", "describe", "design", "despite", "detail",
        "determine", "develop", "development", "die", "difference", "different", "difficult", "dinner",
        "direction", "director", "discover", "discuss", "discussion", "disease", "doctor", "dog",
        "door", "down", "draw", "dream", "drive", "drop", "drug", "during",
        "each", "early", "east", "easy", "eat", "economic", "economy", "edge",
        "education", "effect", "effort", "eight", "either", "election", "else", "employee",
        "end", "energy", "enjoy", "enough", "enter", "entire", "environment", "environmental",
        "especially", "establish", "evening", "event", "ever", "every", "everybody", "everyone",
        "everything", "evidence", "exactly", "example", "executive", "exist", "expect", "experience",
        "expert", "explain", "eye", "face", "fact", "factor", "fail", "fall",
        "family", "far", "fast", "father", "fear", "federal", "feel", "feeling",
        "few", "field", "fight", "figure", "fill", "film", "final", "finally",
        "financial", "find", "fine", "finger", "finish", "fire", "firm", "fish",
        "five", "floor", "fly", "focus", "follow", "food", "foot", "force",
        "foreign", "forget", "form", "former", "forward", "four", "free", "friend",
        "front", "full", "fund", "future", "game", "garden", "gas", "general",
        "generation", "girl", "glass", "global", "goal", "government", "great", "green",
        "ground", "group", "grow", "growth", "guess", "gun", "guy", "hair",
        "half", "hand", "hang", "happen", "happy", "hard", "head", "heat",
        "high", "history", "hit", "hold", "home", "hope", "hospital", "hot",
        "hotel", "hour", "house", "however", "huge", "human", "hundred", "husband",
        "idea", "identify", "image", "imagine", "impact", "important", "improve", "include",
        "including", "increase", "indeed", "indicate", "individual", "industry", "information", "inside",
        "instead", "institution", "interest", "interesting", "international", "interview", "investment", "involve",
        "issue", "item", "job", "join", "keep", "key", "kid", "kill",
        "kind", "kitchen", "knowledge", "land", "language", "large", "last", "late",
        "later", "laugh", "law", "lawyer", "lay", "lead", "leader", "learn",
        "least", "leave", "left", "leg", "legal", "less", "let", "letter",
        "level", "lie", "life", "light", "likely", "line", "list", "listen",
        "little", "live", "local", "long", "lose", "loss", "lot", "love",
        "low", "machine", "magazine", "main", "maintain", "major", "majority", "manage",
        "management", "manager", "many", "market", "marriage", "material", "matter", "may",
        "maybe", "mean", "measure", "media", "medical", "method", "middle", "might",
        "military", "million", "mind", "minute", "miss", "mission", "model", "modern",
        "moment", "nation", "national", "natural", "nature", "near", "nearly", "necessary",
        "need", "network", "news", "newspaper", "next", "nice", "none", "nor",
        "north", "northern", "note",
    ]
}
