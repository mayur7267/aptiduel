import Foundation

// The Streak Tower: every day you play adds a block, milestones get a
// badge. Same rules as the website (web/src/lib/streak.ts). Streaks
// themselves are the server's: one finished duel a day, India time.
public enum Streak {
    public static let milestones = [3, 7, 14, 30, 50, 100, 200, 365]

    public static func isMilestone(_ n: Int) -> Bool { milestones.contains(n) }
    public static func next(after n: Int) -> Int? { milestones.first { $0 > n } }

    public static func title(_ n: Int) -> String {
        switch n {
        case 3: "Hat-trick!"
        case 7: "Week 1 complete!"
        case 14: "Two weeks strong!"
        case 30: "A month of duels!"
        case 50: "Half-century!"
        case 100: "Centurion!"
        case 200: "Unstoppable!"
        case 365: "A whole year!"
        default: "\(n) days!"
        }
    }

    // Each day's block in turn: 0 lime, 1 violet, 2 orange, 3 sky.
    public static func colorIndex(day: Int) -> Int { (max(1, day) - 1) % 4 }

    private static let india = TimeZone(identifier: "Asia/Kolkata")!

    // "2026-11-22": a date as the server counts days.
    public static func istDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = india
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // "THU" for the day `daysAgo` days before today, in India.
    public static func weekday(daysAgo: Int, now: Date = .now) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = india
        f.dateFormat = "EEE"
        return f.string(from: now.addingTimeInterval(-Double(daysAgo) * 86_400)).uppercased()
    }

    // 0 = Monday, in India.
    public static func weekdayIndex(now: Date = .now) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = india
        return (cal.component(.weekday, from: now) + 5) % 7
    }

    // The days of the current streak, when the server can't list them
    // (before 0030): consecutive days ending today, or yesterday.
    public static func days(streak: Int, playedToday: Bool, now: Date = .now) -> [String] {
        (0..<max(0, streak)).reversed().map { i in istDay(now.addingTimeInterval(-Double(i + (playedToday ? 0 : 1)) * 86_400)) }
    }
}

public enum StreakCelebration: Equatable, Sendable {
    case up(from: Int, to: Int, fresh: Bool) // fresh: a new tower after a break
    case fell(from: Int)
}

// The streak this device last showed, per player.
public struct StreakSeen: Codable, Equatable, Sendable {
    public var streak: Int
    public var day: String
    public init(streak: Int, day: String) {
        self.streak = streak
        self.day = day
    }
}

// What to show when the app sees your streak: a bigger number than it last
// celebrated (you played, here or on another device), or a tower that fell.
public func decideStreakCelebration(streak: Int, playedToday: Bool, seen: StreakSeen?) -> StreakCelebration? {
    guard let seen else {
        // First time this device sees the tower: celebrate today's block.
        return streak > 0 && playedToday ? .up(from: streak - 1, to: streak, fresh: streak == 1) : nil
    }
    if streak > seen.streak { return .up(from: seen.streak, to: streak, fresh: seen.streak == 0) }
    if streak > 0 && streak < seen.streak { return .up(from: 0, to: streak, fresh: true) } // missed a day, then played
    if streak == 0 && seen.streak >= 2 { return .fell(from: seen.streak) }
    return nil
}
