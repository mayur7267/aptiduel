import AppCore
import DesignSystem
import Domain
import SwiftUI
import Tiko

public struct PlayerProfileView: View {
    @State private var model: PlayerProfileViewModel

    public init(model: PlayerProfileViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton("Back") { model.close() }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                Group {
                    switch model.load {
                    case .loading:
                        Spinner("Loading player").padding(.top, 80)
                    case .missing:
                        VStack(spacing: 12) {
                            TikoView(mood: .confused, size: 84)
                            Text("Player not found").font(.display(22)).foregroundStyle(Theme.text)
                            Text("They may have deleted their account.").font(.ui(14)).foregroundStyle(Theme.muted)
                        }
                        .padding(.top, 60)
                    case let .failed(message):
                        ErrorNote(message) { Task { await model.fetch() } }
                    case let .loaded(p):
                        profile(p)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .task { await model.fetch() }
    }

    private func profile(_ p: PublicProfile) -> some View {
        let first = PlayerProfileViewModel.shortName(p.name)
        let tier = tierFor(p.rating)
        return VStack(spacing: 14) {
            VStack(spacing: 10) {
                PlayerAvatar(name: p.name, bot: p.isBot, size: 84)
                    .padding(3)
                    .background(Circle().fill(Theme.lime))
                Text(p.name).font(.display(24)).foregroundStyle(Theme.text)
                Text(p.isBot ? (p.tagline ?? "Practice bot")
                     : [p.college, p.gradYear.map { "Batch ’\(String(String($0).suffix(2)))" }].compactMap { $0 }.joined(separator: " · ").nonEmpty ?? "No college added yet")
                    .font(.ui(14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                TierBadge(rating: p.rating, showRating: true)
                HStack(spacing: 14) {
                    if let rank = p.collegeRank { Text("#\(rank) in their college") }
                    if let next = tier.next { Text("\(next.min - p.rating) to \(next.name)") }
                }
                .font(.ui(13)).foregroundStyle(Theme.muted)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Theme.surface
                    RadialGradient(colors: [Theme.lime.opacity(0.16), .clear], center: .top, startRadius: 0, endRadius: 200)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line))

            HStack(spacing: 10) {
                stat("Duels", "\(p.gamesPlayed)")
                stat("Wins", "\(p.wins)")
                stat("Win rate", p.winRate.map { "\($0)%" } ?? "—")
                stat("Best streak", "\(p.streakBest)d")
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent form").font(.display(16)).foregroundStyle(Theme.text)
                    Spacer()
                    if p.streak > 0 {
                        Label("\(p.streak)-day streak", systemImage: "flame.fill").font(.ui(12, .bold)).foregroundStyle(Theme.orange)
                    }
                }
                if p.recent.isEmpty {
                    Text("No finished duels yet.").font(.ui(14)).foregroundStyle(Theme.muted)
                } else {
                    HStack(spacing: 6) {
                        ForEach(Array(p.recent.reversed().enumerated()), id: \.offset) { _, r in
                            Text(r)
                                .font(.mono(14))
                                .foregroundStyle(r == "W" ? Theme.ink : r == "L" ? Theme.redSoft : Theme.soft)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 8).fill(r == "W" ? Theme.lime : r == "L" ? Theme.redTint : Theme.raised))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Last duels: \(p.recent.reversed().joined(separator: ", "))")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)

            if let record = p.vsMe {
                HStack(spacing: 14) {
                    Image(systemName: "trophy.fill").foregroundStyle(Theme.lime)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You vs \(first)").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                        Text(record.played > 0 ? "\(record.played) \(record.played == 1 ? "duel" : "duels") played" : "You haven't played \(first) yet.")
                            .font(.ui(12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if record.played > 0 {
                        (Text("\(record.wins)").foregroundColor(Theme.lime) + Text(" – ").foregroundColor(Theme.faint)
                            + Text("\(record.losses)").foregroundColor(Theme.orange))
                            .font(.mono(24))
                    }
                }
                .padding(16)
                .card(20)
            }

            if p.isMe {
                Button { model.editMine() } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This is how others see you").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                        Text("Edit your name and college on your profile.").font(.ui(13)).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .card(16)
                }
            } else if p.isBot {
                Button("Quick Match") { model.quickMatch() }.buttonStyle(.lime)
            } else {
                Button { model.duel() } label: {
                    Label("Duel \(first) live", systemImage: "bolt.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle(fill: Theme.orange, foreground: Theme.ink, pop: Color(hex: "6b3415")))
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.mono(18)).foregroundStyle(Theme.text)
            Text(label).font(.ui(11, .semibold)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card(16)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
