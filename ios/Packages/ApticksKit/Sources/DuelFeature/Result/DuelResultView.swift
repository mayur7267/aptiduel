import AppCore
import DesignSystem
import Domain
import StoreKit
import SwiftUI

public struct DuelResultView: View {
    @State private var model: DuelResultViewModel
    @Environment(\.requestReview) private var requestReview
    @Environment(ReviewState.self) private var review: ReviewState?

    public init(model: DuelResultViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            if let duel = model.duel {
                content(duel)
            } else if let error = model.error {
                VStack(alignment: .leading, spacing: 16) {
                    ErrorNote(error) { Task { await model.retry() } }
                    Button("Back to home") { model.close() }.font(.ui(14, .semibold)).foregroundStyle(Theme.lime)
                }
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Spinner("Loading result").frame(maxHeight: .infinity)
            }
        }
        .task { await model.load() }
        .task(id: model.isLive) { await model.watchRematch() }
        .task(id: model.duel?.awaitingOpponent == true) { await model.poll() }
        .task(id: model.duel?.outcome) { await askForReview() }
        .animation(.snappy, value: model.duel)
    }

    // After a win, once the player has had a few: the system rating sheet,
    // a couple of seconds in so the result lands first (see ReviewState).
    private func askForReview() async {
        guard let duel = model.duel, duel.outcome == .win, review?.recordWin(in: duel.id) == true else { return }
        try? await Task.sleep(for: .seconds(2))
        if !Task.isCancelled { requestReview() }
    }

    private func content(_ duel: Duel) -> some View {
        let me = duel.me
        let opp = duel.opponent
        let outcome = duel.outcome

        return ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CloseButton("Back to home") { model.close() }
                    Hero(duel: duel, outcome: outcome)
                    if let opp, let outcome { Scoreboard(me: me, opp: opp, outcome: outcome) { model.openPlayer($0) } }
                    if let delta = me.ratingDelta, let before = me.ratingBefore, let after = me.ratingAfter {
                        RatingChange(before: before, after: after, delta: delta)
                        if model.isLive && delta == 0 {
                            Text("Friends move each other's rating once a day, so this one was just for fun.")
                                .font(.ui(13)).foregroundStyle(Theme.muted)
                        }
                    }
                    if model.isLive, let opp, opp.finished {
                        Button { Task { await model.rematchLive() } } label: {
                            Label(model.rematching ? "Opening the room…"
                                  : model.rematchId != nil ? "\(opp.name) is ready: join the rematch" : "Rematch \(opp.name)",
                                  systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressableStyle(fill: Theme.orange, foreground: Theme.ink, pop: Color(hex: "6b3415")))
                        .disabled(model.rematching)
                    }
                    if let review = duel.review { AnswerDots(review: review) }

                    if me.hasGuestName && duel.mode != .daily {
                        Button { model.close(to: .profile) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add your name before you share").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                                    Text("Friends will see “\(me.name)” otherwise.").font(.ui(14)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                            }
                            .padding(16)
                            .card(16)
                        }
                        .buttonStyle(.plain)
                    }

                    actions(duel)

                    if model.showReview, let review = duel.review {
                        Review(duelId: duel.id, items: review, opponentName: opp?.finished == true ? opp?.name : nil)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            if outcome == .win { Confetti() }
        }
    }

    private func actions(_ duel: Duel) -> some View {
        VStack(spacing: 10) {
            if duel.mode == .daily {
                // Sharing the set would show friends today's answers before they play.
                Text("Today's set stays private until it resets at midnight, so nobody sees the answers early. Want to race a friend now? Start a challenge from home.")
                    .font(.ui(14)).foregroundStyle(Theme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(16)
            } else if let code = model.shareCode {
                SharePanel(code: code, text: challengeShareText(duel.me.name, duel.me.correct, duel.me.totalMs, code))
            } else {
                Button { Task { await model.makeShareCode() } } label: {
                    Label(model.sharing ? "Making your link…" : "Challenge friends with your score", systemImage: "bolt.fill")
                        .font(.ui(16, .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, height: 56))
                .disabled(model.sharing)
            }
            HStack(spacing: 10) {
                Button { model.playAgain() } label: {
                    Label(model.rematch.map { "\($0.name) again" } ?? "Quick Match", systemImage: "arrow.clockwise")
                        .font(.ui(15, .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledStyle(fill: Theme.surface, foreground: Theme.text, border: Theme.line, height: 52))
                Button(model.showReview ? "Hide answers" : "Review answers") {
                    withAnimation(.snappy) { model.showReview.toggle() }
                }
                .font(.ui(15, .semibold))
                .buttonStyle(FilledStyle(fill: Theme.surface, foreground: Theme.text, border: Theme.line, height: 52))
                .frame(maxWidth: .infinity)
            }
            if let error = model.error { ErrorNote(error) }
        }
        .padding(.top, 4)
    }
}
