import DesignSystem
import Domain
import SwiftUI

struct QuestsCard: View {
    let me: Me
    let busy: HomeAction?
    let onAction: (String) -> Void

    var body: some View {
        let quests = [
            ("Play the Daily Challenge", me.quests.daily, 1, "daily"),
            ("Win 2 Quick Matches", me.quests.quickWins, 2, "quick"),
            ("Get a friend to accept a challenge", me.quests.accepted, 1, "challenge"),
        ]
        let doneCount = quests.filter { $0.1 >= $0.2 }.count
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today's goals").font(.ui(17, .bold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(doneCount)/\(quests.count) done").font(.ui(12)).monospacedDigit().foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 4)
            ForEach(quests, id: \.0) { title, have, need, action in
                let done = have >= need
                Button { onAction(action) } label: {
                    HStack(spacing: 12) {
                        if done {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(Theme.ink)
                                .frame(width: 24, height: 24).background(Circle().fill(Theme.lime))
                        } else {
                            Circle().strokeBorder(Theme.lineStrong, lineWidth: 2).frame(width: 24, height: 24)
                        }
                        Text(title).font(.ui(14, .semibold))
                            .foregroundStyle(done ? Theme.muted : Theme.text)
                            .strikethrough(done)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text("\(min(have, need))/\(need)").font(.mono(12, .semibold)).foregroundStyle(Theme.muted)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(done || busy != nil)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(20)
    }
}
