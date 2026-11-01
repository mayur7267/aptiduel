import Foundation

// A challenge link's public info (get_challenge).
public struct Challenge: Decodable, Sendable, Hashable {
    public struct Challenger: Decodable, Sendable, Hashable {
        public let name: String
        public let rating: Int
        public let college: String?
        public let gradYear: Int?
    }

    public let code: String
    public let open: Bool
    public let live: Bool? // a live room (create_room) rather than a recorded challenge
    public let started: Bool? // live: the duel has begun
    public let full: Bool? // live: both seats are taken
    public let mySeat: Int? // your seat, when you're in it
    public let challenger: Challenger
    public let challengerFinished: Bool
    public let score: Int
    public let correct: Int
    public let totalMs: Int
    public let acceptedCount: Int
}

// The challenger's own view of their challenge link. nil for anyone else.
public struct ChallengeStatus: Decodable, Sendable, Hashable {
    public struct Mine: Decodable, Sendable, Hashable {
        public let name: String
        public let finished: Bool
        public let score: Int
        public let correct: Int
        public let totalMs: Int
    }

    public struct Friend: Decodable, Sendable, Hashable, Identifiable {
        public let duelId: String // their run: the original duel for the first friend, a copy for later ones
        public let name: String
        public let college: String?
        public let finished: Bool
        public let score: Int
        public let correct: Int
        public let totalMs: Int
        public var id: String { duelId }
    }

    public let duelId: String
    public let code: String
    public let open: Bool
    public let me: Mine
    public let friends: [Friend]
}
