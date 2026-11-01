import DesignSystem
import Domain
import SwiftUI
import Tiko

struct Hero: View {
    let duel: Duel
    let outcome: DuelOutcome?

    var body: some View {
        let me = duel.me
        let opp = duel.opponent
        let summary = "\(me.correct)/5 correct in \(clock(me.totalMs)) · \(me.score) points"
        var title: String
        var line: String
        var tone = Theme.text
        var mood: TikoMood = .happy

        if let outcome, let opp {
            let gap = abs(me.score - opp.score)
            switch outcome {
            case .win:
                title = "You won!"
                line = gap > 0 ? "You beat \(opp.name) by \(gap) points" : "Same points as \(opp.name), but you were faster"
                tone = Theme.lime
                mood = .cheer
            case .loss:
                title = "You lost"
                line = gap > 0 ? "\(opp.name) won by \(gap) points. Run it back?" : "Same points, but \(opp.name) was faster"
                tone = Theme.orange
                mood = .sad
            case .draw:
                title = "It's a draw"
                line = "Same points, same time"
            }
        } else if let opp {
            title = "Waiting for \(opp.name)"
            line = duel.mode == .live
                ? "\(summary). \(opp.name) is on question \(min(opp.answered + 1, 5)) of 5 with \(opp.score) points."
                : "\(summary). This page updates when they finish."
            mood = .think
        } else if duel.mode == .daily {
            title = duel.daily.map { "#\($0.rank) today" } ?? "Daily done"
            line = duel.daily.map { "\(summary). You're #\($0.rank) of \($0.players) who played today's set." } ?? summary
            tone = Theme.violetSoft
            mood = (duel.daily?.rank ?? 99) <= 3 ? .cheer : .happy
        } else if duel.mode == .quick {
            title = "Run saved"
            line = "\(summary). No one near your rating was free, so players who match with you will race this run."
        } else {
            title = "Score set"
            line = "\(summary). Your friends get the same 5 questions."
            mood = .wave
        }

        return VStack(spacing: 8) {
            TikoView(mood: mood, size: 104).popIn()
            Text(title).font(.display(30)).foregroundStyle(tone).padding(.top, 4).multilineTextAlignment(.center)
            Text(line).font(.ui(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
    }
}
