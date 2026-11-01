import DesignSystem
import Domain
import SwiftUI

struct BoardLine: View {
    let row: BoardRow
    var body: some View {
        HStack(spacing: 12) {
            Text("\(row.rank)").font(.ui(14, .bold)).monospacedDigit()
                .foregroundStyle(row.isMe ? Theme.lime : Theme.muted).frame(width: 22, alignment: .leading)
            Avatar(name: row.name, size: 32)
            Text(row.isMe ? "You" : row.name).font(.ui(14, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
            Spacer(minLength: 0)
            Text(grouped(row.rating)).font(.mono(14)).foregroundStyle(Theme.text)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, row.isMe ? 10 : 0)
        .background {
            if row.isMe {
                RoundedRectangle(cornerRadius: 12).fill(Theme.meRow)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.lime, lineWidth: 1.5))
            }
        }
        .padding(.horizontal, row.isMe ? -10 : 0)
    }
}

struct CollegeCard: View {
    let me: Me
    let board: Board?
    let addCollege: () -> Void
    let fullBoard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if me.collegeId == nil {
                Text("Your college board").font(.ui(17, .bold)).foregroundStyle(Theme.text)
                Text("Add your college to see where you rank against your batchmates.").font(.ui(14)).foregroundStyle(Theme.muted)
                Button("Add your college", action: addCollege).font(.ui(14, .semibold)).foregroundStyle(Theme.lime).padding(.top, 4)
            } else {
                let rows = board?.rows ?? []
                let mine = board?.me
                let showMine = mine != nil && !rows.contains { $0.isMe }
                let hidden = mine.map { $0.rank - 1 - rows.count } ?? 0
                HStack {
                    Text(me.college ?? "").font(.ui(17, .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer()
                    Text("By rating").font(.ui(12)).foregroundStyle(Theme.muted)
                }
                if rows.isEmpty {
                    Text("Nobody here is ranked yet. Play a duel to be first.").font(.ui(14)).foregroundStyle(Theme.muted)
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows, id: \.rank) { BoardLine(row: $0) }
                    }
                }
                if showMine, let mine {
                    if hidden > 0 {
                        HStack(spacing: 8) {
                            Rectangle().fill(Theme.line).frame(height: 1)
                            Text("\(hidden) more").font(.ui(12)).foregroundStyle(Theme.faint).fixedSize()
                            Rectangle().fill(Theme.line).frame(height: 1)
                        }
                    }
                    BoardLine(row: mine)
                }
                Button("Full leaderboard", action: fullBoard).font(.ui(14, .semibold)).foregroundStyle(Theme.lime).padding(.top, 4)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(20)
    }
}
