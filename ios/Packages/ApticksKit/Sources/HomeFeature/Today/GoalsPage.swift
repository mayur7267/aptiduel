import DesignSystem
import Domain
import SwiftUI

// One of today's three goals.
struct Goal: Identifiable {
    enum Action { case daily, quick, friend }

    let title: String
    let have: Int
    let need: Int
    let action: Action

    var id: String { title }
    var done: Bool { have >= need }
}

extension Me {
    var goals: [Goal] {
        [
            Goal(title: "Play the Daily Challenge", have: quests.daily, need: 1, action: .daily),
            Goal(title: "Win 2 Quick Matches", have: quests.quickWins, need: 2, action: .quick),
            Goal(title: "Get a friend to accept a challenge", have: quests.accepted, need: 1, action: .friend),
        ]
    }

    var goalsDone: Int { goals.filter(\.done).count }
}

// Today's goals: a bar filling in thirds, and each goal one tap from done.
struct GoalsPage: View {
    let me: Me
    let busy: HomeAction?
    let onAction: (Goal.Action) -> Void

    var body: some View {
        let goals = me.goals
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text("Today's goals").font(.display(19)).foregroundStyle(Theme.text)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    ForEach(goals) { g in
                        Capsule().fill(g.done ? Theme.lime : Theme.line).frame(width: 16, height: 6)
                    }
                }
                .accessibilityHidden(true)
                Text("\(me.goalsDone)/\(goals.count)").font(.mono(14)).foregroundStyle(Theme.lime)
            }
            .padding(.bottom, 2)
            ForEach(goals) { goal in
                Button { onAction(goal.action) } label: {
                    HStack(spacing: 12) {
                        if goal.done {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(Theme.ink)
                                .frame(width: 24, height: 24).background(Circle().fill(Theme.lime))
                        } else {
                            Circle().strokeBorder(Theme.lineStrong, lineWidth: 2).frame(width: 24, height: 24)
                        }
                        Text(goal.title).font(.ui(14, .semibold))
                            .foregroundStyle(goal.done ? Theme.muted : Theme.text)
                            .strikethrough(goal.done)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text("\(min(goal.have, goal.need))/\(goal.need)").font(.mono(12, .semibold)).foregroundStyle(Theme.muted)
                        if !goal.done {
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.faint)
                        }
                    }
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(goal.done || busy != nil)
                .accessibilityLabel(goal.title)
                .accessibilityValue(goal.done ? "Done" : "\(goal.have) of \(goal.need)")
            }
        }
        .deckPage(Theme.surface)
    }
}
