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
    // From search (0027_world_colleges.sql): where it is, and how many
    // players it has. The plain list leaves them out.
    public let city: String?
    public let country: String?
    public let players: Int?

    public init(id: Int, name: String, city: String? = nil, country: String? = nil, players: Int? = nil) {
        self.id = id
        self.name = name
        self.city = city
        self.country = country
        self.players = players
    }

    // "Mumbai, India".
    public var place: String {
        [city, country.flatMap { Locale.current.localizedString(forRegionCode: $0) }]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    // "IN" -> 🇮🇳, or a cap when the country isn't known.
    public var flag: String { College.flag(country) ?? "🎓" }

    public static func flag(_ code: String?) -> String? {
        guard let code, code.count == 2, code.allSatisfy({ $0.isASCII && $0.isUppercase }) else { return nil }
        return String(String.UnicodeScalarView(code.unicodeScalars.compactMap { UnicodeScalar(0x1F1E6 + $0.value - 65) }))
    }
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
