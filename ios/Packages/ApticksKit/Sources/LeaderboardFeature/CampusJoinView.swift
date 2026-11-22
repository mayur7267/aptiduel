import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

// A campus link opened in the app: the college, its top three, and one
// button that joins its board and starts a duel. Someone from another
// college is told before they move.
public struct CampusJoinView: View {
    @State private var model: CampusJoinViewModel

    public init(model: CampusJoinViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton("Back to home") { model.close() }
                Spacer()
                Logo()
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                Group {
                    switch model.load {
                    case .loading:
                        Spinner("Opening your college").padding(.top, 80)
                    case .missing:
                        VStack(spacing: 12) {
                            TikoView(mood: .confused, size: 96)
                            Text("College not found").font(.display(22)).foregroundStyle(Theme.text)
                            Text("Ask whoever sent the link to send it again.").font(.ui(14)).foregroundStyle(Theme.muted)
                        }
                        .padding(.top, 60)
                    case let .failed(message):
                        ErrorNote(message) { Task { await model.fetch() } }
                    case let .loaded(card, _):
                        content(card)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .task { await model.fetch() }
    }

    private func content(_ c: CollegeCard) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Chip("Your college's leaderboard", fg: Theme.lime, bg: Theme.limeTint)
            Text("Join \(c.name) on Apticks")
                .font(.display(c.name.count > 28 ? 26 : 30))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(c.players > 0
                 ? "\(grouped(c.players)) \(c.players == 1 ? "student plays" : "students play") for \(c.name). Play quick 1v1 duels in Aptitude, Coding and English, and see who's #1."
                 : "Nobody from \(c.name) is on the board yet. Play one quick 1v1 duel and you're #1.")
                .font(.ui(15)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            board(c)
                .overlay(alignment: .topLeading) { TikoView(mood: .wave, size: 64).offset(x: -6, y: -54) }
                .padding(.top, 34)

            actions(c)
        }
    }

    // The college's top three, or a #1 spot waiting for its first player.
    private func board(_ c: CollegeCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(c.college.flag) \(c.name)").font(.ui(16, .bold)).foregroundStyle(Theme.text)
                Text([c.college.place, "\(grouped(c.players)) \(c.players == 1 ? "player" : "players")"].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.ui(12)).foregroundStyle(Theme.muted)
            }
            if c.top.isEmpty {
                HStack(spacing: 12) {
                    Text("#1").font(.display(28)).foregroundStyle(Theme.lime)
                    Text("is free. The first duel from \(c.name) takes it.").font(.ui(14)).foregroundStyle(Theme.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(c.top.enumerated()), id: \.offset) { i, p in
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.mono(14)).foregroundStyle(i == 0 ? Theme.lime : Theme.muted).frame(width: 18)
                            PlayerAvatar(name: p.name, bot: false, size: 32)
                            Text(p.name).font(.ui(15, .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                            Spacer()
                            Text(grouped(p.rating)).font(.mono(14)).foregroundStyle(Theme.soft)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .card(14, fill: Theme.raised)
                    }
                    if c.players > 3 {
                        Text("and \(grouped(c.players - 3)) more").font(.ui(12)).foregroundStyle(Theme.muted).padding(.leading, 12)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(24, border: Theme.lime.opacity(0.4), width: 2)
    }

    @ViewBuilder
    private func actions(_ c: CollegeCard) -> some View {
        if model.isHere {
            VStack(alignment: .leading, spacing: 12) {
                Text("You're already on \(c.name)'s board.").font(.ui(15, .semibold)).foregroundStyle(Theme.lime)
                Button { model.play() } label: { Label("Play a duel", systemImage: "bolt.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.lime)
                Button("See the board") { model.seeBoard() }
                    .buttonStyle(FilledStyle(fill: Theme.surface, foreground: Theme.text, border: Theme.line))
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if let other = model.otherCollege {
                    Text("You play for **\(other)** now. Joining moves you to \(c.name)'s board.")
                        .font(.ui(14)).foregroundStyle(Theme.muted)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(16)
                }
                Button { Task { await model.join() } } label: {
                    Label(model.joining ? "Joining…" : model.otherCollege != nil ? "Switch college and play" : "Join and play a duel",
                          systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.lime)
                .disabled(model.joining)
                if let error = model.error { Text(error).font(.ui(13)).foregroundStyle(Theme.redSoft) }
                Button("Not now") { model.close() }
                    .font(.ui(14, .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
