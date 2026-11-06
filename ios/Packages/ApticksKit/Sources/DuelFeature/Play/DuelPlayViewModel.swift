import AppCore
import Domain
import Foundation
import Networking

public enum DuelPhase: Sendable {
    case loading, question, submitting, reveal
}

// A duel in progress (port of web/src/app/duel/[id]/duel-play.tsx). The
// server keeps the time; this shows it, sends answers and replays a
// finished opponent's run against yours.
@MainActor
@Observable
public final class DuelPlayViewModel {
    public let duelId: String
    public private(set) var duel: Duel?
    public private(set) var question: Question?
    public private(set) var phase: DuelPhase = .loading
    public private(set) var chosen: Int?
    public private(set) var result: AnswerResult?
    public private(set) var score = 0
    public private(set) var marks: [AnswerMark] = []
    public private(set) var remainingMs = 0
    public private(set) var error: String?
    // Question whose opponent result has been shown (see submit).
    public private(set) var oppRevealed = -1
    public var leaving = false
    // A live duel is a race: both players' progress as it happens.
    public private(set) var race: LiveState?

    private var deadline = Date()
    private var answered = -1
    private var followUps: [Task<Void, Never>] = []

    private let api: any APIClient
    private let router: AppRouter
    private let now: () -> Date
    private let sleep: (Duration) async -> Void

    public init(duelId: String, api: any APIClient, router: AppRouter, now: @escaping () -> Date = Date.init,
                sleep: @escaping (Duration) async -> Void = Wait.real) {
        self.duelId = duelId
        self.api = api
        self.router = router
        self.now = now
        self.sleep = sleep
    }

    // MARK: Derived state

    public var urgent: Bool { remainingMs < 10_000 && phase == .question }

    public var fractionLeft: Double {
        guard let question, question.timeLimitMs > 0 else { return 0 }
        return Double(remainingMs) / Double(question.timeLimitMs)
    }

    // The opponent revealed their answer to the question on screen.
    public var revealedHere: Bool { phase == .reveal && oppRevealed == question?.qIndex }

    public var opponentReplay: OpponentReplay {
        guard let question else { return OpponentReplay(timeline: [], question: 0, elapsedMs: 0, revealed: false) }
        return OpponentReplay(timeline: timeline ?? [], question: question.qIndex,
                              elapsedMs: question.timeLimitMs - remainingMs, revealed: revealedHere)
    }

    // Racing a finished run: you've answered, they haven't yet.
    public var waitingFor: String? {
        guard phase == .reveal, !revealedHere, timeline != nil else { return nil }
        return duel?.opponent?.name
    }

    // Which question's clock is running (-1 when none is).
    public var clockKey: Int { phase == .question ? question?.qIndex ?? -1 : -1 }

    // MARK: Actions

    public var isLive: Bool { duel?.mode == .live }

    // A finished opponent's run to replay against yours. Not in a live
    // race, where their real progress shows instead.
    private var timeline: [TimelineStep]? { isLive ? nil : duel?.opponentTimeline }

    // About every 1.5 s in a live race. It also keeps you marked as
    // present, since someone gone for 45 s forfeits the rest.
    public func followRace() async {
        while isLive, !Task.isCancelled {
            if let s = try? await api.liveState(duelId) { race = s }
            await sleep(.milliseconds(1500))
        }
    }

    public func load() async {
        do {
            async let d = api.duel(duelId)
            async let n = api.nextQuestion(duelId)
            let (duel, next) = try await (d, n)
            self.duel = duel
            // Restore right/wrong dots for questions answered earlier.
            marks = (duel.myAnswers ?? []).map { $0.correct ? .right : .wrong }
            show(next)
        } catch {
            // A live duel opened before its countdown ended goes back to it.
            if error.localizedDescription == "The duel hasn't started yet." {
                router.open(.live(duelId))
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    // The server says which question is still open, so an answer that
    // failed to send can be sent again.
    public func retry() async {
        error = nil
        answered = -1
        await load()
    }

    // Counts down the question on screen and answers for you at zero.
    public func runClock() async {
        while phase == .question, !Task.isCancelled {
            remainingMs = msLeft()
            if remainingMs == 0 {
                // In a task of its own: answering stops the clock, and the
                // view then cancels the clock's task, which would cancel
                // the answer on its way and leave the duel stuck here.
                await Task { await submit(nil) }.value
                return
            }
            await sleep(.milliseconds(100))
        }
    }

    public func submit(_ choice: Int?) async {
        guard let q = question, phase == .question, answered != q.qIndex else { return }
        answered = q.qIndex
        let myMs = q.timeLimitMs - msLeft()
        chosen = choice
        phase = .submitting
        do {
            let r = try await api.submitAnswer(duelId, question: q.qIndex, choice: choice)
            result = r
            score = r.score
            marks.append(r.correct ? .right : .wrong)
            phase = .reveal
            // If you beat the opponent to it, they answer a moment later
            // rather than at the same instant, which would look rigged.
            let step = timeline?.first { $0.qIndex == q.qIndex }
            let wait = step.map { $0.ms > myMs ? min($0.ms - myMs, 1200 + Int.random(in: 0..<2000)) : 0 } ?? 0
            later(wait) { self.oppRevealed = q.qIndex }
            later(wait + (r.correct ? 900 : 1500)) {
                if r.done { self.router.open(.result(self.duelId)) } else { await self.loadNext() }
            }
        } catch {
            // Usually a double submit after coming back: just move on.
            if error.localizedDescription.contains("already answered") {
                await loadNext()
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    // Back from the background: catch up with the server's clock.
    public func catchUp() async {
        if phase == .question { await loadNext() }
    }

    // The clock keeps running on the server, so leaving isn't free.
    public func leave() {
        stop()
        router.close()
    }

    public func stop() {
        followUps.forEach { $0.cancel() }
        followUps = []
    }

    // Waits for scheduled reveals and moves (for tests).
    func settle() async {
        while !followUps.isEmpty {
            await followUps.removeFirst().value
        }
    }

    // MARK: Private

    private func msLeft() -> Int { max(0, Int(deadline.timeIntervalSince(now()) * 1000)) }

    private func later(_ ms: Int, _ fn: @escaping () async -> Void) {
        followUps.append(Task {
            await sleep(.milliseconds(ms))
            if !Task.isCancelled { await fn() }
        })
    }

    private func loadNext() async {
        do {
            show(try await api.nextQuestion(duelId))
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func show(_ next: QuestionView) {
        switch next {
        case .done:
            router.open(.result(duelId))
        case let .question(n):
            deadline = now().addingTimeInterval(Double(n.remainingMs) / 1000)
            question = n
            score = n.score
            chosen = nil
            result = nil
            remainingMs = n.remainingMs
            if marks.count < n.qIndex { marks += Array(repeating: .unknown, count: n.qIndex - marks.count) }
            phase = .question
        }
    }
}
