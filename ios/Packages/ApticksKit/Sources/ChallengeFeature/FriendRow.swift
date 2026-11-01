import DesignSystem
import Domain
import SwiftUI
import Tiko

struct FriendRow: View {
    let friend: ChallengeStatus.Friend
    let me: ChallengeStatus.Mine

    var body: some View {
        let f = friend
        var chip: (String, Color, Color) = ("Playing now", Theme.muted, Theme.raised)
        if f.finished && !me.finished {
            chip = ("Done · \(f.correct)/5 in \(clock(f.totalMs))", Theme.soft, Theme.raised)
        } else if f.finished {
            let outcome = DuelOutcome(myScore: me.score, myMs: me.totalMs, theirScore: f.score, theirMs: f.totalMs)
            chip = outcome == .draw ? ("Tie", Theme.soft, Theme.raised)
                : outcome == .win ? ("You won", Theme.lime, Theme.limeTint)
                : ("\(f.name.split(separator: " ").first.map(String.init) ?? f.name) won", Theme.redSoft, Theme.redTint)
        }
        return HStack(spacing: 12) {
            Avatar(name: f.name, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(f.name).font(.ui(14, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                if let college = f.college { Text(college).font(.ui(12)).foregroundStyle(Theme.muted).lineLimit(1) }
            }
            Spacer(minLength: 0)
            Chip(chip.0, fg: chip.1, bg: chip.2)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
