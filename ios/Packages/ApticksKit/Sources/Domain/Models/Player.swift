import Foundation

// Shapes returned by the database functions in supabase/migrations. They
// mirror web/src/lib/api.ts. Keys arrive in snake_case; see Wire.decoder.

// One side of a duel.
public struct Player: Decodable, Sendable, Hashable {
    public let id: String? // for opening their profile
    public let seat: Int
    public let name: String
    public let rating: Int
    public let college: String?
    public let isBot: Bool
    public let tagline: String? // bots only
    public let score: Int
    public let correct: Int
    public let totalMs: Int
    public let answered: Int
    public let finished: Bool
    public let isReplay: Bool
    public let ratingBefore: Int?
    public let ratingAfter: Int?

    public var hasGuestName: Bool { isGuestName(name) }

    // The rating change from this duel, unless it was a replay of a challenge.
    public var ratingDelta: Int? {
        guard let ratingBefore, let ratingAfter, !isReplay else { return nil }
        return ratingAfter - ratingBefore
    }
}

// Guests are named "Player 1234" until they pick a name.
public func isGuestName(_ name: String) -> Bool { name.wholeMatch(of: /Player \d{4}/) != nil }
