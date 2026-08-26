import Foundation

/// A handful of pairs so the strip is not blank on the first day.
///
/// Deliberately tiny and deliberately generic. A large seed would drown the
/// user's own phrases under general English for weeks — and general English is
/// the part a keyboard is *worst* at guessing, because everyone's differs. The
/// job here is only to stop day one feeling broken; personal counts overtake
/// these within a few dozen sentences, since every real use adds a vote and
/// these start with one.
public enum NextWordSeed {

    public static var model: NextWordModel {
        NextWordModel(seed: pairs)
    }

    static let pairs: [(context: String, next: String)] = [
        ("i", "am"), ("i", "have"), ("i", "think"), ("i", "will"),
        ("im", "not"), ("im", "going"),
        ("thank", "you"), ("thanks", "for"),
        ("how", "are"), ("how", "much"), ("how", "about"),
        ("how are", "you"),
        ("are", "you"), ("are", "not"),
        ("what", "is"), ("what", "do"), ("what", "time"),
        ("what is", "the"),
        ("do", "you"), ("do", "not"),
        ("do you", "have"), ("do you", "want"), ("do you", "know"),
        ("can", "you"), ("can", "i"),
        ("can you", "send"), ("can you", "please"),
        ("let", "me"), ("let me", "know"),
        ("see", "you"), ("see you", "soon"), ("see you", "tomorrow"),
        ("good", "morning"), ("good", "night"), ("good", "luck"),
        ("have", "a"), ("have a", "good"),
        ("on", "the"), ("in", "the"), ("at", "the"), ("to", "the"),
        ("of", "the"), ("for", "the"), ("from", "the"), ("with", "the"),
        ("is", "the"), ("was", "the"), ("it", "is"), ("it", "was"),
        ("this", "is"), ("that", "is"), ("there", "is"), ("here", "is"),
        ("we", "are"), ("they", "are"), ("you", "are"), ("he", "is"),
        ("she", "is"), ("it", "will"),
        ("going", "to"), ("want", "to"), ("need", "to"), ("have", "to"),
        ("trying", "to"), ("used", "to"), ("able", "to"),
        ("a", "little"), ("a", "few"), ("a", "lot"),
        ("as", "soon"), ("as soon", "as"),
        ("right", "now"), ("just", "now"),
        ("please", "let"), ("please", "send"), ("please", "check"),
        ("sorry", "for"), ("sorry", "about"),
        ("no", "problem"), ("not", "sure"), ("of", "course"),
        ("by", "the"), ("by the", "way"),
        ("talk", "to"), ("talk to", "you"),
        ("call", "you"), ("call", "me"),
        ("send", "me"), ("send", "it"),
        ("i am", "going"), ("i am", "not"), ("i am", "here"),
        ("i will", "be"), ("i will", "call"), ("i will", "send"),
        ("i have", "a"), ("i have", "to"),
        ("i think", "so"), ("i think", "it"),
        ("be", "there"), ("be", "here"),
        ("in", "a"), ("in a", "minute"),
        ("last", "night"), ("next", "week"), ("this", "week"),
        ("today", "is"), ("tomorrow", "is"),
        ("where", "are"), ("where are", "you"),
        ("when", "you"), ("when", "will"),
        ("why", "did"), ("why", "not"),
        ("who", "is"), ("which", "one"),
    ]
}
