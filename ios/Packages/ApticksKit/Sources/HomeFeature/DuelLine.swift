import DesignSystem
import Domain
import SwiftUI

// Everything a recent-duel line shows, worked out from its summary.
struct DuelLine: Identifiable {
    struct Status: Equatable {
        let text: String
        let fg: Color
        let bg: Color
    }

    let id: String
    let finished: Bool
    let daily: Bool
    let hasOpponent: Bool
    let bot: Bool
    let who: String
    let sub: String
    let status: Status
    let score: String
    let delta: Int?

    init(_ d: DuelSummary) {
        let hasOpp = d.opponentName != nil
        let settled = d.finished && hasOpp && d.opponentFinished == true
        let opp = d.opponentScore ?? 0
        let outcome = settled ? DuelOutcome(myScore: d.score, myMs: d.totalMs, theirScore: opp, theirMs: d.opponentTotalMs ?? 0) : nil
        let bot = d.opponentIsBot ?? false

        var who = d.opponentName ?? ""
        var sub = d.company.map { "\($0) practice" } ?? d.opponentCollege ?? (d.mode == .quick ? "Quick Match" : "Challenge")
        if d.mode == .daily {
            who = "Daily Challenge"
            sub = "Same set for everyone"
        } else if !hasOpp && d.mode == .quick {
            who = "Solo run"
            sub = "Saved for others to race"
        } else if !hasOpp {
            who = "Your challenge"
            sub = "Waiting for a friend"
        } else if d.isReplay {
            sub = "Played your challenge"
        } else if bot {
            sub = d.company.map { "\($0) practice · bot" } ?? "Practice bot"
        }

        status = !d.finished ? Status(text: "Unfinished", fg: Theme.orange, bg: Theme.orangeTint)
            : d.mode == .daily ? Status(text: "Done", fg: Theme.violet, bg: Theme.violetTint)
            : !hasOpp ? Status(text: "Waiting", fg: Theme.muted, bg: Theme.raised)
            : d.opponentFinished != true ? Status(text: "Playing", fg: Theme.muted, bg: Theme.raised)
            : outcome == .draw ? Status(text: "Tie", fg: Theme.soft, bg: Theme.raised)
            : outcome == .win ? Status(text: "Won 🏆", fg: Theme.lime, bg: Theme.limeTint)
            : Status(text: "Lost", fg: Theme.redSoft, bg: Theme.redTint)

        id = d.id
        finished = d.finished
        daily = d.mode == .daily
        hasOpponent = hasOpp
        self.bot = bot
        self.who = who
        self.sub = sub
        score = settled ? "\(d.score) – \(opp)" : d.finished ? String(d.score) : "—"
        delta = if let b = d.ratingBefore, let a = d.ratingAfter, !d.isReplay { a - b } else { nil }
    }
}
