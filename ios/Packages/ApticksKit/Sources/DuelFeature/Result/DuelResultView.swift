import AppCore
import DesignSystem
import Domain
import StoreKit
import SwiftUI

public struct DuelResultView: View {
    @State private var model: DuelResultViewModel
    @Environment(\.requestReview) private var requestReview
    @Environment(ReviewState.self) private var review: ReviewState?
    @Environment(ReminderState.self) private var reminders: ReminderState?
    @State private var reminderOn = false

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
                        RatingChange(before: before, after: after, delta: delta, label: duel.playedSubject.ratingLabel)
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

                    if model.askForName, let profile = model.profile {
                        NameForm(current: profile.name, saving: model.savingName, error: model.nameError) { name in
                            Task { await model.saveName(name) }
                        }
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

    // Once, after a finished Daily: an 8 pm nudge on days you haven't played.
    @ViewBuilder
    private var reminderOffer: some View {
        if let reminders, reminders.shouldOffer || reminderOn {
            VStack(alignment: .leading, spacing: 10) {
                if reminderOn {
                    Label("Reminder on: 8 pm, on days you haven't played.", systemImage: "bell.fill")
                        .font(.ui(14, .semibold)).foregroundStyle(Theme.lime)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Want a nudge at 8 pm?").font(.ui(14, .semibold)).foregroundStyle(Theme.text)
                        Text("Only on days you haven't played the Daily. Turn it off any time in Profile.")
                            .font(.ui(13)).foregroundStyle(Theme.muted)
                    }
                    HStack(spacing: 10) {
                        Button("Remind me") {
                            Task {
                                let ok = await reminders.turnOn(doneToday: true, streak: model.profile?.streak ?? 0)
                                withAnimation(.snappy) { reminderOn = ok }
                            }
                        }
                        .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, radius: 12, height: 40))
                        Button("Not now") { withAnimation(.snappy) { reminders.dismissOffer() } }
                            .font(.ui(14, .semibold)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(16)
        }
    }

    @ViewBuilder
    private var story: some View {
        if let data = model.story { StoryButton(data: data) { model.sharedStory() } }
    }

    private func actions(_ duel: Duel) -> some View {
        VStack(spacing: 10) {
            if duel.mode == .daily, let text = model.dailyText {
                // A grid that gives nothing away: friends see how you did,
                // never which questions, and the link says who sent it.
                SharePanel(code: duel.code, text: text, link: Links.daily(duel.code), label: "WhatsApp", copyText: true,
                           onShare: { model.logShare(.daily, $0) }) { story }
            } else if duel.mode != .daily, let code = model.shareCode {
                SharePanel(code: code, text: challengeShareText(duel.me.name, duel.me.correct, duel.me.totalMs, code, duel.subject ?? .aptitude),
                           label: "WhatsApp", onShare: { model.logShare(.challenge, $0) }) { story }
            } else if duel.mode != .daily {
                HStack(spacing: 10) {
                    Button { Task { await model.makeShareCode() } } label: {
                        Label(model.sharing ? "Making link…" : "Challenge friends", systemImage: "bolt.fill")
                            .font(.ui(16, .bold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FilledStyle(fill: Theme.lime, foreground: Theme.ink, height: 56))
                    .disabled(model.sharing)
                    story
                }
            }
            if duel.mode == .daily { reminderOffer }
            if model.storyShared {
                Text("Your link is copied too: add it to your Story with Instagram's Link sticker.")
                    .font(.ui(13)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
