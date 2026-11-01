import Foundation

// A live friend duel as of now (live_state, supabase/migrations/
// 0013_live_duels.sql): the lobby, the countdown, then a race where both
// players' progress shows as it happens. Times are server epoch
// milliseconds; nowMs lets the screen line its clock up with the server's.
public struct LiveState: Decodable, Sendable, Hashable {
    public enum Status: String, Decodable, Sendable, Hashable {
        case waiting, starting, playing, done, async, closed
    }

    public let id: String
    public let code: String
    public let status: Status
    public let isHost: Bool
    public let nowMs: Int
    public let startsAtMs: Int? // when the first question opens for both
    public let me: LivePlayer
    public let opponent: LivePlayer?
    public let rematchId: String?
}

public struct LivePlayer: Decodable, Sendable, Hashable {
    public let id: String?
    public let seat: Int
    public let name: String
    public let rating: Int
    public let college: String?
    public let present: Bool // their screen checked in during the last 15 s
    public let answered: Int // questions answered so far
    public let correct: Int
    public let score: Int
    public let finished: Bool
    public let marks: [Bool] // right or wrong, question by question
}

// Opening a room, or joining one from its link. A room nobody waited for
// has become an ordinary challenge (mode says which).
public struct RoomRef: Decodable, Sendable, Hashable {
    public let duelId: String
    public let code: String
}

public struct JoinedRoom: Decodable, Sendable, Hashable {
    public let duelId: String
    public let mode: DuelMode
}

// Anyone's public profile (get_profile). vsMe is your own record against
// them, when you're signed in and it isn't you.
public struct PublicProfile: Decodable, Sendable, Hashable {
    public struct Record: Decodable, Sendable, Hashable {
        public let played: Int
        public let wins: Int
        public let losses: Int
    }

    public let id: String
    public let name: String
    public let college: String?
    public let gradYear: Int?
    public let rating: Int
    public let gamesPlayed: Int
    public let wins: Int
    public let streak: Int
    public let streakBest: Int
    public let isBot: Bool
    public let tagline: String?
    public let isMe: Bool
    public let joined: String
    public let collegeRank: Int?
    public let recent: [String] // "W", "L" or "D", newest first
    public let vsMe: Record?

    public var winRate: Int? { gamesPlayed > 0 ? Int((Double(wins) / Double(gamesPlayed) * 100).rounded()) : nil }
}
