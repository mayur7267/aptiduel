import Foundation

// The signed-in player (get_me).
public struct Me: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let rating: Int
    public let gamesPlayed: Int
    public let wins: Int
    public let streak: Int
    public let streakBest: Int
    public let playedToday: Bool
    public let collegeId: Int?
    public let college: String?
    public let gradYear: Int?
    public let collegeRank: Int?
    public let todayIdx: Int // 0 = Monday, IST
    public let dailyWeek: [Bool] // daily challenge done, Monday to Sunday
    public let quests: Quests

    public var hasGuestName: Bool { isGuestName(name) }
}

// Today's three goals.
public struct Quests: Decodable, Sendable, Hashable {
    public let daily: Int
    public let quickWins: Int
    public let accepted: Int
}

public struct College: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
}

// Whether this device's account is a guest or saved under an email.
public struct AccountInfo: Sendable, Hashable {
    public let guest: Bool
    public let email: String?

    public init(guest: Bool, email: String?) {
        self.guest = guest
        self.email = email
    }
}
