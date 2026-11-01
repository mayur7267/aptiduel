import AppCore
import DesignSystem
import Domain
import SwiftUI

public struct LeaderboardView: View {
    @Bindable var model: LeaderboardViewModel
    @Environment(AppRouter.self) private var router
    @Environment(CompanionState.self) private var companion

    public init(model: LeaderboardViewModel) { self.model = model }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Logo()
                HStack {
                    Text("Leaderboard").font(.display(24)).foregroundStyle(Theme.text)
                    Spacer()
                    Chip("By rating", fg: Theme.muted, bg: Theme.surface).overlay(Capsule().strokeBorder(Theme.line))
                }
                Picker("Leaderboard", selection: $model.scope) {
                    ForEach(BoardScope.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                if let error = model.error { ErrorNote(error) }
                if model.board == nil && model.error == nil { Spinner("Loading rankings") }
                if let board = model.board { BoardView(board: board, open: { model.open($0) }) { router.tab = .profile } }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.load() }
        // Your row, when it isn't already in the list above.
        .safeAreaInset(edge: .bottom) {
            if let board = model.board, let pinned = board.pinnedMe {
                Row(row: pinned, scope: board.scope)
                    .padding(.horizontal, 16)
                    .padding(.trailing, COMPANION_SIZE + 20)
                    .padding(.bottom, 8)
                    .shadow(color: Theme.ink.opacity(0.9), radius: 12, y: -8)
            }
        }
        .task(id: "\(model.scope)-\(router.refresh)") { await model.load() }
        .onChange(of: model.board, initial: true) { companion.pages[.ranks] = model.companionPage }
    }
}

private struct BoardView: View {
    let board: Board
    let open: (BoardRow) -> Void // someone else's row opens their profile
    let addCollege: () -> Void

    var body: some View {
        if board.needsCollege {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick your college first").font(.ui(18, .bold)).foregroundStyle(Theme.text)
                Text("Add your college to your profile to see how you rank against your batchmates.").font(.ui(14)).foregroundStyle(Theme.muted)
                Button("Add your college", action: addCollege).buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, radius: 12, height: 42))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)
        } else {
            let top = Array(board.rows.prefix(3))
            let rest = board.rows.count >= 3 ? Array(board.rows.dropFirst(3)) : board.rows
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(board.scope == .college ? board.college ?? "" : "All India").font(.ui(17, .bold)).foregroundStyle(Theme.text)
                        Text("\(grouped(board.players)) \(board.players == 1 ? "player" : "players") ranked by rating · +/− is this week's change")
                            .font(.ui(12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if let me = board.me {
                        Chip("You're #\(me.rank)" + (me.weekDelta != 0 ? " · \(signed(me.weekDelta)) this week" : ""),
                             fg: Theme.lime, bg: Theme.limeTint)
                    }
                }
                if board.rows.isEmpty {
                    Text("Nobody is ranked here yet. Play a Quick Match to take the top spot.")
                        .font(.ui(14)).foregroundStyle(Theme.muted)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                } else {
                    if top.count == 3 { Podium(rows: top, onOpen: open) }
                    VStack(spacing: 8) {
                        ForEach(Array(rest.enumerated()), id: \.offset) { i, r in
                            Row(row: r, scope: board.scope)
                                .contentShape(Rectangle())
                                .onTapGesture { open(r) }
                                .accessibilityAddTraits(r.id != nil && !r.isMe ? .isButton : [])
                                .rise(min(Double(i) * 0.03, 0.3))
                        }
                    }
                }
                if board.me == nil {
                    Text("You're not ranked yet. Play a duel to get on the board.").font(.ui(14)).foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

private struct Podium: View {
    let rows: [BoardRow]
    let onOpen: (BoardRow) -> Void // someone else's row opens their profile
    @State private var raised = false

    var body: some View {
        // Second, first, third, so the winner stands in the middle.
        let order = [rows[1], rows[0], rows[2]]
        let styles: [(height: CGFloat, fill: Color, fg: Color, pop: Color, ring: Color, size: CGFloat)] = [
            (80, Theme.raised, Theme.soft, Theme.surface, Theme.soft, 52),
            (112, Theme.lime, Theme.ink, Theme.limePop, Theme.lime, 64),
            (64, Theme.raised, Theme.orange, Theme.surface, Theme.orange, 52),
        ]
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                let r = order[i]
                let s = styles[i]
                VStack(spacing: 8) {
                    Avatar(name: r.name, size: s.size).padding(3).background(Circle().fill(s.ring))
                    Text(r.isMe ? "You" : r.name).font(.ui(14, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(grouped(r.rating)).font(.mono(12, .regular)).foregroundStyle(Theme.muted)
                    Text("\(r.rank)")
                        .font(.display(24))
                        .foregroundStyle(s.fg)
                        .frame(maxWidth: .infinity)
                        .frame(height: raised ? s.height : 0)
                        .background(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 16).fill(s.fill))
                        .background(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 16).fill(s.pop).offset(x: 4, y: 4))
                        .clipped()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onOpen(r) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Top three")
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) { raised = true }
        }
    }
}

private struct Row: View {
    let row: BoardRow
    let scope: BoardScope

    var body: some View {
        let meta = scope == .india ? row.college : batch(row.gradYear)
        HStack(spacing: 12) {
            Text("\(row.rank)").font(.mono(14)).foregroundStyle(row.isMe ? Theme.lime : Theme.muted).frame(width: 28, alignment: .leading)
            Avatar(name: row.name, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name + (row.isMe ? " (You)" : "")).font(.ui(14, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                if let meta { Text(meta).font(.ui(12)).foregroundStyle(Theme.muted).lineLimit(1) }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 1) {
                Text(grouped(row.rating)).font(.mono(14)).foregroundStyle(Theme.text)
                if row.weekDelta != 0 {
                    Text(signed(row.weekDelta)).font(.ui(12, .semibold)).foregroundStyle(row.weekDelta > 0 ? Theme.lime : Theme.red)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .card(16, fill: row.isMe ? Theme.meRow : Theme.surface, border: row.isMe ? Theme.lime : Theme.line, width: row.isMe ? 1.5 : 1)
    }
}
