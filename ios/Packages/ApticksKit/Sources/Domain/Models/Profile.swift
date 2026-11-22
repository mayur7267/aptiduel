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

// The Streak Tower page (my_streak, 0030_streak_tower.sql): days are the
// India dates you played in the last 120 days.
public struct StreakInfo: Decodable, Sendable, Hashable {
    public struct Top: Decodable, Sendable, Hashable {
        public let name: String
        public let streak: Int
        public let isMe: Bool
        public init(name: String, streak: Int, isMe: Bool) {
            self.name = name
            self.streak = streak
            self.isMe = isMe
        }
    }

    public let streak: Int
    public let best: Int
    public let playedToday: Bool
    public let days: [String]
    public let college: String?
    public let collegeTop: [Top]

    public init(streak: Int, best: Int, playedToday: Bool, days: [String], college: String? = nil, collegeTop: [Top] = []) {
        self.streak = streak
        self.best = best
        self.playedToday = playedToday
        self.days = days
        self.college = college
        self.collegeTop = collegeTop
    }
}

// One college as its campus link shows it (college_card, 0029_campus_links.sql):
// how many play for it, and its top three as first name and initial.
public struct CollegeCard: Decodable, Sendable, Hashable {
    public struct Top: Decodable, Sendable, Hashable {
        public let name: String
        public let rating: Int
        public init(name: String, rating: Int) {
            self.name = name
            self.rating = rating
        }
    }

    public let id: Int
    public let name: String
    public let city: String?
    public let country: String?
    public let players: Int
    public let top: [Top]

    public init(id: Int, name: String, city: String? = nil, country: String? = nil, players: Int = 0, top: [Top] = []) {
        self.id = id
        self.name = name
        self.city = city
        self.country = country
        self.players = players
        self.top = top
    }

    public var college: College { College(id: id, name: name, city: city, country: country, players: players) }
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
