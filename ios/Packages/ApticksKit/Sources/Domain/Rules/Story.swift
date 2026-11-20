import Foundation

// What goes on the Story picture of a result (port of storyData in
// web/src/app/duel/[id]/result/duel-result.tsx).
public struct StoryData: Sendable, Hashable {
    public let chip: String // "DAILY · 14 NOV", "QUICK MATCH"
    public let headline: String // "I won!", "Today's Daily"
    public let correct: Int
    public let score: Int
    public let time: String // "0:42"
    public let grid: [Bool]
    public let extra: String? // "Beat Mayur by 149 points", "#3 of 40 today"

    public init(chip: String, headline: String, correct: Int, score: Int, time: String, grid: [Bool], extra: String?) {
        self.chip = chip
        self.headline = headline
        self.correct = correct
        self.score = score
        self.time = time
        self.grid = grid
        self.extra = extra
    }

    // Right or wrong, question by question; nil until all five are known.
    public static func grid(_ duel: Duel) -> [Bool]? {
        guard let review = duel.review, review.count == 5 else { return nil }
        return review.sorted { $0.qIndex < $1.qIndex }.map(\.isCorrect)
    }

    public init?(duel: Duel, today: String = istToday()) {
        guard let grid = Self.grid(duel) else { return nil }
        let me = duel.me
        let chip: String
        if duel.mode == .daily {
            chip = "DAILY · \(shortDay(today).uppercased())"
        } else if let company = duel.company {
            chip = "\(company.uppercased()) PRACTICE"
        } else if duel.playedSubject != .aptitude {
            chip = "\(duel.playedSubject.label.uppercased()) MATCH"
        } else {
            chip = [DuelMode.quick: "QUICK MATCH", .live: "LIVE DUEL", .challenge: "CHALLENGE"][duel.mode] ?? "APTITUDE DUEL"
        }
        var headline = "My score"
        var extra: String?
        if duel.mode == .daily {
            headline = "Today's Daily"
            extra = duel.daily.map { "#\($0.rank) of \($0.players) today" }
        } else if let opp = duel.opponent, duel.outcome == .win {
            headline = "I won!"
            let gap = me.score - opp.score
            // A win over a bot doesn't name the bot.
            extra = opp.isBot ? nil : gap > 0 ? "Beat \(opp.name) by \(gap) points" : "Beat \(opp.name) on time"
        } else if duel.outcome == .draw {
            headline = "It's a draw"
        }
        self.init(chip: chip, headline: headline, correct: me.correct, score: me.score, time: clock(me.totalMs), grid: grid, extra: extra)
    }
}
